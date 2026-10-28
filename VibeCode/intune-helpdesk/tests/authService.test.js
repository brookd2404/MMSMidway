jest.mock('../src/auth/msalConfig', () => ({
  __esModule: true,
  default: {},
  isEntraConfigured: true,
}));

jest.mock('@azure/msal-browser', () => {
  const actual = jest.requireActual('@azure/msal-browser');
  return {
    ...actual,
    PublicClientApplication: jest.fn(() => ({
      getActiveAccount: jest.fn(),
      getAllAccounts: jest.fn(),
      acquireTokenSilent: jest.fn(),
      acquireTokenPopup: jest.fn(),
    })),
  };
});

test('requests incremental action consent only when explicitly permitted', async () => {
  const account = { homeAccountId: 'active' };
  const scopes = ['https://graph.microsoft.com/BitlockerKey.Read.All'];
  msalInstance.getActiveAccount.mockReturnValue(account);
  msalInstance.acquireTokenSilent.mockRejectedValue(new InteractionRequiredAuthError('interaction_required'));
  msalInstance.acquireTokenPopup.mockResolvedValue({ accessToken: 'action-token' });
  await expect(getGraphAccessToken(scopes, true)).resolves.toBe('action-token');
  expect(msalInstance.acquireTokenPopup).toHaveBeenCalledWith({ account, scopes });
});

const { InteractionRequiredAuthError } = require('@azure/msal-browser');
const { msalInstance, getGraphAccessToken, graphScopes } = require('../src/auth/authService');

beforeEach(() => {
  msalInstance.getActiveAccount.mockReturnValue(null);
  msalInstance.getAllAccounts.mockReturnValue([]);
});

test('rejects a request before sign-in without acquiring a token', async () => {
  await expect(getGraphAccessToken()).rejects.toThrow('Sign in with Microsoft');
  expect(msalInstance.acquireTokenSilent).not.toHaveBeenCalled();
});

test('acquires a delegated token for the active account', async () => {
  const account = { homeAccountId: 'active' };
  msalInstance.getActiveAccount.mockReturnValue(account);
  msalInstance.acquireTokenSilent.mockResolvedValue({ accessToken: 'delegated-token' });
  await expect(getGraphAccessToken()).resolves.toBe('delegated-token');
  expect(msalInstance.acquireTokenSilent).toHaveBeenCalledWith({ account, scopes: graphScopes });
});

test('uses a cached account after a page reload', async () => {
  const account = { homeAccountId: 'cached' };
  msalInstance.getAllAccounts.mockReturnValue([account]);
  msalInstance.acquireTokenSilent.mockResolvedValue({ accessToken: 'cached-token' });
  await expect(getGraphAccessToken()).resolves.toBe('cached-token');
  expect(msalInstance.acquireTokenSilent).toHaveBeenCalledWith({ account, scopes: graphScopes });
});

test('provides reauthentication guidance when consent or interaction is required', async () => {
  msalInstance.getActiveAccount.mockReturnValue({ homeAccountId: 'active' });
  msalInstance.acquireTokenSilent.mockRejectedValue(new InteractionRequiredAuthError('interaction_required'));
  await expect(getGraphAccessToken()).rejects.toThrow('Sign out and sign in again');
});
