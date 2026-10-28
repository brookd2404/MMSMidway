export interface Device {
    id: string;
    name: string;
    complianceStatus: string;
    lastCheckIn: Date;
    bitLockerKey?: string;
}

export interface DeviceActionResponse {
    success: boolean;
    message: string;
}

export interface AuditLog {
    id: string;
    action: string;
    timestamp: Date;
    deviceId: string;
    userId: string;
}