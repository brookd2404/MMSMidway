import { Client } from '@microsoft/microsoft-graph-client';
import { Device } from '../types/index';

const graphClient = Client.init({
    authProvider: (done) => {
        // Implement your authentication logic here
        done(null, 'YOUR_ACCESS_TOKEN'); // Replace with actual token retrieval logic
    }
});

export const getDeviceById = async (deviceId: string): Promise<Device> => {
    try {
        const device = await graphClient.api(`/devices/${deviceId}`).get();
        return device as Device;
    } catch (error) {
        throw new Error(`Error fetching device: ${error.message}`);
    }
};

export const getBitLockerRecoveryKeys = async (deviceId: string): Promise<any> => {
    try {
        const recoveryKeys = await graphClient.api(`/devices/${deviceId}/bitLockerRecoveryKeys`).get();
        return recoveryKeys;
    } catch (error) {
        throw new Error(`Error fetching BitLocker recovery keys: ${error.message}`);
    }
};

export const checkDeviceCompliance = async (deviceId: string): Promise<any> => {
    try {
        const complianceStatus = await graphClient.api(`/devices/${deviceId}/complianceState`).get();
        return complianceStatus;
    } catch (error) {
        throw new Error(`Error checking device compliance: ${error.message}`);
    }
};

export const performRemoteAction = async (deviceId: string, action: string): Promise<any> => {
    try {
        const response = await graphClient.api(`/devices/${deviceId}/remoteActions/${action}`).post();
        return response;
    } catch (error) {
        throw new Error(`Error performing remote action: ${error.message}`);
    }
};