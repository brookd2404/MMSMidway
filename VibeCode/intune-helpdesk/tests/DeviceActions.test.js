const React = require('react');
const { render, screen, fireEvent, act, waitFor } = require('@testing-library/react');
jest.mock('../src/services/deviceService', () => ({
  syncDevice: jest.fn(),
  wipeDevice: jest.fn(),
  listBitLockerRecoveryKeys: jest.fn(),
  getBitLockerRecoveryKey: jest.fn(),
}));
const { syncDevice, wipeDevice, listBitLockerRecoveryKeys, getBitLockerRecoveryKey } = require('../src/services/deviceService');
const DeviceActions = require('../src/components/DeviceActions').default;
const device = { id: 'intune-id', name: 'Helpdesk-PC', azureADDeviceId: 'entra-id', operatingSystem: 'Windows' };
const password = Array(8).fill('123456').join('-');

beforeEach(() => {
  syncDevice.mockReset().mockResolvedValue(undefined);
  wipeDevice.mockReset().mockResolvedValue(undefined);
  listBitLockerRecoveryKeys.mockReset().mockResolvedValue([
    { id: 'key-1', volumeType: 'operatingSystemVolume', createdDateTime: 'today' },
  ]);
  getBitLockerRecoveryKey.mockReset().mockResolvedValue(password);
});
afterEach(() => jest.useRealTimers());

test('does not request actions or secrets on mount', () => {
  render(React.createElement(DeviceActions, { device }));
  expect(syncDevice).not.toHaveBeenCalled();
  expect(wipeDevice).not.toHaveBeenCalled();
  expect(listBitLockerRecoveryKeys).not.toHaveBeenCalled();
  expect(getBitLockerRecoveryKey).not.toHaveBeenCalled();
});

test('opening and cancelling wipe never sends a wipe request and clears confirmation', async () => {
  render(React.createElement(DeviceActions, { device }));
  fireEvent.click(screen.getByRole('button', { name: 'Wipe device' }));
  expect(screen.getByRole('dialog', { name: 'Confirm device wipe' })).toBeTruthy();
  expect(screen.getByText('Intune device ID: intune-id')).toBeTruthy();
  fireEvent.change(screen.getByLabelText('Device name confirmation'), { target: { value: device.name } });
  fireEvent.click(screen.getByRole('button', { name: 'Cancel' }));
  await waitFor(() => expect(screen.queryByRole('dialog')).toBeNull());
  expect(wipeDevice).not.toHaveBeenCalled();
  fireEvent.click(screen.getByRole('button', { name: 'Wipe device' }));
  expect(screen.getByLabelText('Device name confirmation').value).toBe('');
  expect(screen.getByRole('button', { name: 'Permanently wipe device' }).disabled).toBe(true);
});

test('wipe requires exact device name and submits only once while in progress', async () => {
  let resolve;
  wipeDevice.mockReturnValue(new Promise(done => { resolve = done; }));
  render(React.createElement(DeviceActions, { device }));
  fireEvent.click(screen.getByRole('button', { name: 'Wipe device' }));
  const confirm = screen.getByRole('button', { name: 'Permanently wipe device' });
  const input = screen.getByLabelText('Device name confirmation');
  for (const value of ['', 'helpdesk-pc', 'Helpdesk-PC ']) {
    fireEvent.change(input, { target: { value } });
    expect(confirm.disabled).toBe(true);
    fireEvent.click(confirm);
    expect(wipeDevice).not.toHaveBeenCalled();
  }
  fireEvent.change(input, { target: { value: device.name } });
  expect(confirm.disabled).toBe(false);
  fireEvent.click(confirm);
  fireEvent.click(confirm);
  expect(wipeDevice).toHaveBeenCalledTimes(1);
  expect(wipeDevice).toHaveBeenCalledWith('intune-id');
  await act(async () => resolve());
  expect(await screen.findByText(/Wipe requested. This does not confirm completion/)).toBeTruthy();
  await waitFor(() => expect(screen.queryByRole('dialog')).toBeNull());
  expect(screen.getByRole('button', { name: 'Wipe device' }).disabled).toBe(true);
});

test('wipe failure is surfaced without claiming success or automatically retrying', async () => {
  wipeDevice.mockRejectedValue(new Error('HTTP 403: wipe denied'));
  render(React.createElement(DeviceActions, { device }));
  fireEvent.click(screen.getByRole('button', { name: 'Wipe device' }));
  fireEvent.change(screen.getByLabelText('Device name confirmation'), { target: { value: device.name } });
  fireEvent.click(screen.getByRole('button', { name: 'Permanently wipe device' }));
  expect(await screen.findByText('HTTP 403: wipe denied')).toBeTruthy();
  expect(screen.queryByText(/Wipe requested/)).toBeNull();
  expect(wipeDevice).toHaveBeenCalledTimes(1);
});

test('wipe is disabled on unsupported platforms', () => {
  render(React.createElement(DeviceActions, { device: { ...device, operatingSystem: 'macOS' } }));
  expect(screen.getByRole('button', { name: 'Wipe device' }).disabled).toBe(true);
});

test('an unnamed device requires typing its Intune ID instead', async () => {
  render(React.createElement(DeviceActions, { device: { ...device, name: '' } }));
  fireEvent.click(screen.getByRole('button', { name: 'Wipe device' }));
  const confirm = screen.getByRole('button', { name: 'Permanently wipe device' });
  expect(confirm.disabled).toBe(true);
  fireEvent.change(screen.getByLabelText('Device ID confirmation'), { target: { value: device.id } });
  fireEvent.click(confirm);
  expect(await screen.findByText(/Wipe requested/)).toBeTruthy();
});

test('sync uses the Intune ID and reports requested rather than completed', async () => {
  render(React.createElement(DeviceActions, { device }));
  fireEvent.click(screen.getByRole('button', { name: 'Sync device' }));
  expect(await screen.findByText(/Sync requested/)).toBeTruthy();
  expect(syncDevice).toHaveBeenCalledWith('intune-id');
});

test('shows action errors rather than success', async () => {
  syncDevice.mockRejectedValue(new Error('HTTP 403: missing action permission'));
  render(React.createElement(DeviceActions, { device }));
  fireEvent.click(screen.getByRole('button', { name: 'Sync device' }));
  expect(await screen.findByText('HTTP 403: missing action permission')).toBeTruthy();
  expect(screen.queryByText(/Sync requested/)).toBeNull();
});

test('lists by Entra ID and reveals only after a separate click, then hides on request', async () => {
  render(React.createElement(DeviceActions, { device }));
  fireEvent.click(screen.getByRole('button', { name: 'Get BitLocker recovery keys' }));
  const reveal = await screen.findByRole('button', { name: 'Reveal recovery key key-1' });
  expect(listBitLockerRecoveryKeys).toHaveBeenCalledWith('entra-id');
  expect(getBitLockerRecoveryKey).not.toHaveBeenCalled();
  fireEvent.click(reveal);
  expect(await screen.findByText(password)).toBeTruthy();
  fireEvent.click(screen.getByRole('button', { name: 'Hide recovery key' }));
  expect(screen.queryByText(password)).toBeNull();
});

test('automatically clears a revealed password after 60 seconds', async () => {
  render(React.createElement(DeviceActions, { device }));
  fireEvent.click(screen.getByRole('button', { name: 'Get BitLocker recovery keys' }));
  const reveal = await screen.findByRole('button', { name: 'Reveal recovery key key-1' });
  jest.useFakeTimers();
  await act(async () => { fireEvent.click(reveal); });
  expect(screen.getByText(password)).toBeTruthy();
  act(() => jest.advanceTimersByTime(60000));
  expect(screen.queryByText(password)).toBeNull();
});

test('does not retain an old device password after unmount', async () => {
  const view = render(React.createElement(DeviceActions, { device }));
  fireEvent.click(screen.getByRole('button', { name: 'Get BitLocker recovery keys' }));
  fireEvent.click(await screen.findByRole('button', { name: 'Reveal recovery key key-1' }));
  await screen.findByText(password);
  view.unmount();
  render(React.createElement(DeviceActions, { device: { ...device, id: 'other' } }));
  expect(screen.queryByText(password)).toBeNull();
});

test('handles no escrowed keys', async () => {
  listBitLockerRecoveryKeys.mockResolvedValue([]);
  render(React.createElement(DeviceActions, { device }));
  fireEvent.click(screen.getByRole('button', { name: 'Get BitLocker recovery keys' }));
  expect(await screen.findByText(/No escrowed BitLocker/)).toBeTruthy();
});

test('disables BitLocker lookup for non-Windows devices', () => {
  render(React.createElement(DeviceActions, { device: { ...device, operatingSystem: 'Android' } }));
  expect(screen.getByRole('button', { name: 'Get BitLocker recovery keys' }).disabled).toBe(true);
});

test('hides a password when the tab becomes hidden', async () => {
  render(React.createElement(DeviceActions, { device }));
  fireEvent.click(screen.getByRole('button', { name: 'Get BitLocker recovery keys' }));
  fireEvent.click(await screen.findByRole('button', { name: 'Reveal recovery key key-1' }));
  await screen.findByText(password);
  const hidden = jest.spyOn(document, 'hidden', 'get').mockReturnValue(true);
  act(() => { document.dispatchEvent(new Event('visibilitychange')); });
  expect(screen.queryByText(password)).toBeNull();
  hidden.mockRestore();
});

test('prevents duplicate sync submissions while awaiting Graph', async () => {
  let resolve;
  syncDevice.mockReturnValue(new Promise(done => { resolve = done; }));
  render(React.createElement(DeviceActions, { device }));
  const button = screen.getByRole('button', { name: 'Sync device' });
  fireEvent.click(button);
  fireEvent.click(button);
  expect(syncDevice).toHaveBeenCalledTimes(1);
  expect(button.disabled).toBe(true);
  await act(async () => resolve());
});
