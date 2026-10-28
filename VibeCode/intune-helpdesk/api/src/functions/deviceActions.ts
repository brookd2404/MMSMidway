import { GraphService } from '../services/graphService';
import { DeviceActionResponse } from '../types/index';

export const wipeDevice = async (deviceId: string): Promise<DeviceActionResponse> => {
    try {
        const response = await GraphService.wipeDevice(deviceId);
        return response;
    } catch (error) {
        throw new Error(`Failed to wipe device: ${error.message}`);
    }
};

export const restartDevice = async (deviceId: string): Promise<DeviceActionResponse> => {
    try {
        const response = await GraphService.restartDevice(deviceId);
        return response;
    } catch (error) {
        throw new Error(`Failed to restart device: ${error.message}`);
    }
};

export const getBitLockerRecoveryKey = async (deviceId: string): Promise<DeviceActionResponse> => {
    try {
        const response = await GraphService.getBitLockerRecoveryKey(deviceId);
        return response;
    } catch (error) {
        throw new Error(`Failed to retrieve BitLocker recovery key: ${error.message}`);
    }
};

export const checkDeviceCompliance = async (deviceId: string): Promise<DeviceActionResponse> => {
    try {
        const response = await GraphService.checkDeviceCompliance(deviceId);
        return response;
    } catch (error) {
        throw new Error(`Failed to check device compliance: ${error.message}`);
    }
};