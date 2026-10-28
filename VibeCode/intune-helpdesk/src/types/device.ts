export interface Device {
    id: string;
    name: string;
    complianceStatus: string;
    lastCheckIn: string;
    alerts?: string[];
    azureADDeviceId?: string;
    operatingSystem?: string;
}

export interface BitLockerRecoveryKey {
    id: string;
    createdDateTime: string;
    volumeType: string;
}

export type DeviceAction = 'wipe' | 'restart' | 'update';