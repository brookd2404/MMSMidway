import { InteractionRequiredAuthError, PublicClientApplication } from '@azure/msal-browser';
import msalConfig, { isEntraConfigured } from './msalConfig';

export const graphScopes = ['https://graph.microsoft.com/DeviceManagementManagedDevices.Read.All'];
export const syncScopes = ['https://graph.microsoft.com/DeviceManagementManagedDevices.PrivilegedOperations.All'];
export const bitLockerScopes = ['https://graph.microsoft.com/BitlockerKey.Read.All'];
export const msalInstance = isEntraConfigured ? new PublicClientApplication(msalConfig) : null;

export const getGraphAccessToken = async (scopes = graphScopes, interactive = false): Promise<string> => {
  if (!msalInstance) {
    throw new Error('Configure the Microsoft Entra client and tenant IDs before signing in.');
  }
  const account = msalInstance.getActiveAccount() ?? msalInstance.getAllAccounts()[0];
  if (!account) {
    throw new Error('Sign in with Microsoft before loading Intune devices.');
  }
  try {
    const result = await msalInstance.acquireTokenSilent({ account, scopes });
    return result.accessToken;
  } catch (error) {
    if (error instanceof InteractionRequiredAuthError) {
      if (interactive) {
        const result = await msalInstance.acquireTokenPopup({ account, scopes });
        return result.accessToken;
      }
      throw new Error('Your session or consent needs attention. Sign out and sign in again to authorize Intune access.');
    }
    throw error;
  }
};
