const React = require('react');
const { render, screen, fireEvent, waitFor } = require('@testing-library/react');

jest.mock('../src/auth/authService', () => ({
  msalInstance: {},
  graphScopes: ['https://graph.microsoft.com/DeviceManagementManagedDevices.Read.All'],
}));
jest.mock('@azure/msal-react', () => ({
  MsalProvider: ({ children }) => children,
  useMsal: jest.fn(),
  useIsAuthenticated: jest.fn(),
}));
jest.mock('../src/services/deviceService', () => ({
  getDeviceStatus: jest.fn(),
  fetchDevices: jest.fn(),
  getDeviceDetails: jest.fn(),
}));

const { useMsal, useIsAuthenticated } = require('@azure/msal-react');
const { getDeviceStatus } = require('../src/services/deviceService');
const App = require('../src/App').default;

let instance;
beforeEach(() => {
  instance = {
    loginPopup: jest.fn(),
    setActiveAccount: jest.fn(),
    logoutPopup: jest.fn(),
    getActiveAccount: jest.fn(),
  };
  useMsal.mockReturnValue({ instance, inProgress: 'none', accounts: [] });
  useIsAuthenticated.mockReturnValue(false);
});

test('requires sign-in before the dashboard requests device data', () => {
  render(React.createElement(App));
  expect(screen.getByRole('button', { name: 'Sign in with Microsoft' })).toBeTruthy();
  expect(getDeviceStatus).not.toHaveBeenCalled();
});

test('requests only the read-only scope when the user signs in', async () => {
  const account = { homeAccountId: 'account' };
  instance.loginPopup.mockResolvedValue({ account });
  render(React.createElement(App));
  fireEvent.click(screen.getByRole('button', { name: 'Sign in with Microsoft' }));
  await waitFor(() => expect(instance.setActiveAccount).toHaveBeenCalledWith(account));
  expect(instance.loginPopup).toHaveBeenCalledWith({
    scopes: ['https://graph.microsoft.com/DeviceManagementManagedDevices.Read.All'],
  });
});

test('shows sign-in failures', async () => {
  instance.loginPopup.mockRejectedValue(new Error('Consent was declined'));
  render(React.createElement(App));
  fireEvent.click(screen.getByRole('button', { name: 'Sign in with Microsoft' }));
  expect(await screen.findByText('Consent was declined')).toBeTruthy();
});

test('shows Graph permission guidance and supports retry', async () => {
  useIsAuthenticated.mockReturnValue(true);
  getDeviceStatus
    .mockRejectedValueOnce(new Error('HTTP 403: Check admin consent'))
    .mockResolvedValueOnce([]);
  render(React.createElement(App));
  expect(await screen.findByText('HTTP 403: Check admin consent')).toBeTruthy();
  fireEvent.click(screen.getByRole('button', { name: 'Retry' }));
  expect(await screen.findByText('No Intune managed devices were returned for this account.')).toBeTruthy();
  expect(getDeviceStatus).toHaveBeenCalledTimes(2);
});
