import { BitLockerRecoveryKey, Device } from '../types/device';
import { bitLockerScopes, getGraphAccessToken, graphScopes, syncScopes } from '../auth/authService';

const graphRoot = 'https://graph.microsoft.com/v1.0/';
const devicesPath = 'deviceManagement/managedDevices';
const fields = 'id,deviceName,complianceState,lastSyncDateTime';

interface ManagedDevice {
  id: string;
  deviceName: string;
  complianceState: string;
  lastSyncDateTime: string;
  azureADDeviceId?: string;
  operatingSystem?: string;
}

interface DevicePage {
  value: ManagedDevice[];
  '@odata.nextLink'?: string;
}

const request = async (
  url: string,
  scopes = graphScopes,
  method = 'GET',
  interactive = false,
  body?: string,
): Promise<Response> => {
  if (!url.startsWith(graphRoot)) {
    throw new Error('Refusing to send a Graph access token to an unexpected endpoint.');
  }
  const accessToken = await getGraphAccessToken(scopes, interactive);
  const response = await fetch(url, {
    ...(method === 'GET' ? {} : { method }),
    cache: 'no-store',
    ...(body === undefined ? {} : { body }),
    headers: {
      Authorization: `Bearer ${accessToken}`,
      Accept: 'application/json',
      ...(body === undefined ? {} : { 'Content-Type': 'application/json' }),
    },
  });
  if (!response.ok) {
    const guidance = response.status === 401
      ? 'Sign out and sign in again.'
      : response.status === 403
        ? `Check admin consent for ${scopes.map(scope => scope.split('/').pop()).join(', ')}, your Intune license, and the required Intune/Entra role.`
        : response.status === 429
          ? 'Microsoft Graph is throttling requests. Wait before retrying.'
          : 'Check Microsoft Graph availability and retry.';
    throw new Error(`Microsoft Graph device request failed (HTTP ${response.status}). ${guidance}`);
  }
  return response;
};

const toDevice = (device: ManagedDevice): Device => ({
  id: device.id,
  name: device.deviceName,
  complianceStatus: device.complianceState,
  lastCheckIn: device.lastSyncDateTime,
  alerts: device.complianceState === 'noncompliant' ? ['Device is not compliant'] : [],
});

export const fetchDevices = async (): Promise<Device[]> => {
  const devices: Device[] = [];
  let url: string | undefined = `${graphRoot}${devicesPath}?$select=${fields}`;
  const visited = new Set<string>();
  while (url) {
    if (visited.has(url)) {
      throw new Error('Microsoft Graph returned a repeated device page. Retry loading devices.');
    }
    visited.add(url);
    const page: DevicePage = await (await request(url)).json();
    devices.push(...page.value.map(toDevice));
    url = page['@odata.nextLink'];
  }
  return devices;
};

export const getDeviceDetails = async (deviceId: string): Promise<Device> => {
  const device: ManagedDevice = await (await request(
    `${graphRoot}${devicesPath}/${encodeURIComponent(deviceId)}?$select=${fields},azureADDeviceId,operatingSystem`,
  )).json();
  return { ...toDevice(device), azureADDeviceId: device.azureADDeviceId, operatingSystem: device.operatingSystem };
};

export const getDeviceStatus = fetchDevices;

export const syncDevice = async (deviceId: string): Promise<void> => {
  await request(
    `${graphRoot}${devicesPath}/${encodeURIComponent(deviceId)}/syncDevice`,
    syncScopes, 'POST', true,
  );
};

export const wipeDevice = async (deviceId: string): Promise<void> => {
  await request(
    `${graphRoot}${devicesPath}/${encodeURIComponent(deviceId)}/wipe`,
    syncScopes, 'POST', true,
    JSON.stringify({ keepEnrollmentData: false, keepUserData: false }),
  );
};

const recoveryKeysPath = `${graphRoot}informationProtection/bitlocker/recoveryKeys`;
const guidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export const listBitLockerRecoveryKeys = async (azureADDeviceId: string): Promise<BitLockerRecoveryKey[]> => {
  if (!guidPattern.test(azureADDeviceId) || azureADDeviceId === '00000000-0000-0000-0000-000000000000') {
    throw new Error('This device has no valid Microsoft Entra device ID for BitLocker key lookup.');
  }
  const keys: BitLockerRecoveryKey[] = [];
  let url: string | undefined = `${recoveryKeysPath}?$filter=${encodeURIComponent(`deviceId eq '${azureADDeviceId}'`)}`;
  const visited = new Set<string>();
  while (url) {
    if (visited.has(url)) throw new Error('Microsoft Graph returned a repeated recovery key page.');
    visited.add(url);
    const page: { value: BitLockerRecoveryKey[]; '@odata.nextLink'?: string } =
      await (await request(url, bitLockerScopes, 'GET', true)).json();
    keys.push(...page.value.map(({ id, createdDateTime, volumeType }) => ({ id, createdDateTime, volumeType })));
    url = page['@odata.nextLink'];
  }
  return keys;
};

export const getBitLockerRecoveryKey = async (keyId: string): Promise<string> => {
  const result: { key?: string } = await (await request(
    `${recoveryKeysPath}/${encodeURIComponent(keyId)}?$select=key`,
    bitLockerScopes, 'GET', true,
  )).json();
  if (!result.key || !/^\d{6}(-\d{6}){7}$/.test(result.key)) {
    throw new Error('Microsoft Graph did not return a valid BitLocker recovery password. Check BitlockerKey.Read.All consent and your Entra role.');
  }
  return result.key;
};