jest.mock('../src/auth/authService', () => ({
  getGraphAccessToken: jest.fn(),
  graphScopes: ['https://graph.microsoft.com/DeviceManagementManagedDevices.Read.All'],
  syncScopes: ['https://graph.microsoft.com/DeviceManagementManagedDevices.PrivilegedOperations.All'],
  bitLockerScopes: ['https://graph.microsoft.com/BitlockerKey.Read.All'],
}));

const { getGraphAccessToken } = require('../src/auth/authService');
const { fetchDevices, getDeviceDetails, syncDevice, wipeDevice, listBitLockerRecoveryKeys, getBitLockerRecoveryKey } = require('../src/services/deviceService');

const root = 'https://graph.microsoft.com/v1.0/deviceManagement/managedDevices';
const managedDevice = {
  id: 'intune-id',
  deviceName: 'Helpdesk-PC',
  complianceState: 'noncompliant',
  lastSyncDateTime: '2026-10-26T19:00:00Z',
};

beforeEach(() => {
  global.fetch = jest.fn();
  getGraphAccessToken.mockResolvedValue('test-token');
});

const respond = (body) => ({ ok: true, json: async () => body });

test('wipe sends explicit destructive options to the managed device endpoint and handles 204', async () => {
  const json = jest.fn();
  fetch.mockResolvedValue({ ok: true, status: 204, json });
  await expect(wipeDevice('intune/id')).resolves.toBeUndefined();
  expect(fetch).toHaveBeenCalledWith(`${root}/intune%2Fid/wipe`, {
    method: 'POST',
    cache: 'no-store',
    headers: {
      Authorization: 'Bearer test-token',
      Accept: 'application/json',
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ keepEnrollmentData: false, keepUserData: false }),
  });
  expect(json).not.toHaveBeenCalled();
  expect(getGraphAccessToken).toHaveBeenCalledWith(
    ['https://graph.microsoft.com/DeviceManagementManagedDevices.PrivilegedOperations.All'], true,
  );
});

test('wipe authorization failure names the privileged operation permission', async () => {
  fetch.mockResolvedValue({ ok: false, status: 403 });
  await expect(wipeDevice('device')).rejects.toThrow('DeviceManagementManagedDevices.PrivilegedOperations.All');
  expect(fetch).toHaveBeenCalledTimes(1);
});

test('requests delegated Graph data, maps fields and follows all pages', async () => {
  fetch
    .mockResolvedValueOnce(respond({ value: [managedDevice], '@odata.nextLink': `${root}?$skiptoken=next` }))
    .mockResolvedValueOnce(respond({ value: [{ ...managedDevice, id: 'second', complianceState: 'compliant' }] }));

  const devices = await fetchDevices();

  expect(fetch).toHaveBeenNthCalledWith(1, expect.stringContaining(root + '?$select='), {
    cache: 'no-store',
    headers: { Authorization: 'Bearer test-token', Accept: 'application/json' },
  });

  expect(fetch).toHaveBeenNthCalledWith(2, `${root}?$skiptoken=next`, expect.any(Object));
  expect(devices).toEqual([
    {
      id: 'intune-id',
      name: 'Helpdesk-PC',
      complianceStatus: 'noncompliant',
      lastCheckIn: '2026-10-26T19:00:00Z',
      alerts: ['Device is not compliant'],
    },
    expect.objectContaining({ id: 'second', alerts: [] }),
  ]);
});

  test('sync posts without a body and accepts 204 without parsing JSON', async () => {
    const json = jest.fn();
    fetch.mockResolvedValue({ ok: true, status: 204, json });
    await expect(syncDevice('device/id')).resolves.toBeUndefined();
    expect(fetch).toHaveBeenCalledWith(`${root}/device%2Fid/syncDevice`, expect.objectContaining({ method: 'POST' }));
    expect(fetch.mock.calls[0][1].body).toBeUndefined();
    expect(json).not.toHaveBeenCalled();
    expect(getGraphAccessToken).toHaveBeenCalledWith(
      ['https://graph.microsoft.com/DeviceManagementManagedDevices.PrivilegedOperations.All'], true,
    );
  });

  test('lists recovery metadata using the Entra device ID across pages, without revealing passwords', async () => {
    const id = '11111111-2222-3333-4444-555555555555';
    const next = 'https://graph.microsoft.com/v1.0/informationProtection/bitlocker/recoveryKeys?$skiptoken=next';
    fetch.mockResolvedValueOnce(respond({
      value: [{ id: 'key-1', createdDateTime: 'today', volumeType: 'operatingSystemVolume', key: 'must-not-be-returned' }],
      '@odata.nextLink': next,
    })).mockResolvedValueOnce(respond({ value: [] }));
    await expect(listBitLockerRecoveryKeys(id)).resolves.toEqual([
      { id: 'key-1', createdDateTime: 'today', volumeType: 'operatingSystemVolume' },
    ]);
    expect(decodeURIComponent(fetch.mock.calls[0][0])).toContain(`$filter=deviceId eq '${id}'`);
    expect(fetch.mock.calls[0][0]).not.toContain('$select=key');
    expect(fetch).toHaveBeenCalledTimes(2);
  });

  test.each(['', 'intune-id', '00000000-0000-0000-0000-000000000000'])('rejects invalid Entra device ID %s before lookup', async id => {
    await expect(listBitLockerRecoveryKeys(id)).rejects.toThrow('valid Microsoft Entra device ID');
    expect(fetch).not.toHaveBeenCalled();
  });

  test('reveals only the explicitly selected key with no-store caching', async () => {
    const key = Array(8).fill('123456').join('-');
    fetch.mockResolvedValue(respond({ key }));
    await expect(getBitLockerRecoveryKey('selected-key')).resolves.toBe(key);
    expect(fetch).toHaveBeenCalledWith(
      'https://graph.microsoft.com/v1.0/informationProtection/bitlocker/recoveryKeys/selected-key?$select=key',
      expect.objectContaining({ cache: 'no-store' }),
    );
    expect(getGraphAccessToken).toHaveBeenCalledWith(['https://graph.microsoft.com/BitlockerKey.Read.All'], true);
  });

  test('fails explicitly when Graph omits the recovery password', async () => {
    fetch.mockResolvedValue(respond({}));
    await expect(getBitLockerRecoveryKey('key')).rejects.toThrow('did not return a valid BitLocker');
  });

  test('sync permission errors name the required action scope', async () => {
    fetch.mockResolvedValue({ ok: false, status: 403 });
    await expect(syncDevice('device')).rejects.toThrow('DeviceManagementManagedDevices.PrivilegedOperations.All');
  });
test('returns an empty list when Graph reports no devices', async () => {
  fetch.mockResolvedValue(respond({ value: [] }));
  await expect(fetchDevices()).resolves.toEqual([]);
});

test('uses the managed device endpoint and encodes the detail ID', async () => {
  fetch.mockResolvedValue(respond({ ...managedDevice, azureADDeviceId: 'entra-id', operatingSystem: 'Windows' }));
  await expect(getDeviceDetails('id/with space')).resolves.toMatchObject({
    name: 'Helpdesk-PC', azureADDeviceId: 'entra-id', operatingSystem: 'Windows',
  });
  expect(fetch).toHaveBeenCalledWith(expect.stringContaining(`${root}/id%2Fwith%20space?`), expect.any(Object));
});

test.each([
  [401, 'Sign out and sign in again'],
  [403, 'DeviceManagementManagedDevices.Read.All'],
  [429, 'throttling'],
  [500, 'availability'],
])('reports HTTP %s with actionable guidance', async (status, message) => {
  fetch.mockResolvedValue({ ok: false, status });
  await expect(fetchDevices()).rejects.toThrow(message);
});

test('does not fetch if token acquisition fails', async () => {
  getGraphAccessToken.mockRejectedValue(new Error('Sign in first'));
  await expect(fetchDevices()).rejects.toThrow('Sign in first');
  expect(fetch).not.toHaveBeenCalled();
});

test('does not leak the bearer token to a foreign pagination URL', async () => {
  fetch.mockResolvedValue(respond({ value: [], '@odata.nextLink': 'https://example.invalid/devices' }));
  await expect(fetchDevices()).rejects.toThrow('unexpected endpoint');
  expect(fetch).toHaveBeenCalledTimes(1);
});

test('rejects repeated pagination links rather than looping', async () => {
  const next = `${root}?$skiptoken=loop`;
  fetch.mockResolvedValue(respond({ value: [], '@odata.nextLink': next }));
  await expect(fetchDevices()).rejects.toThrow('repeated device page');
  expect(fetch).toHaveBeenCalledTimes(2);
});
