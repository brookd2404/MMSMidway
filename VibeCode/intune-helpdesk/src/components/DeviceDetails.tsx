import React, { useEffect, useState } from 'react';
import { RouteComponentProps } from 'react-router-dom';
import { getDeviceDetails } from '../services/deviceService';
import { Device } from '../types/device';
import DeviceActions from './DeviceActions';
import { Alert, Button, CircularProgress, Typography, Card, CardContent } from '@mui/material';

const DeviceDetails: React.FC<RouteComponentProps<{ id: string }>> = ({ match }) => {
    const deviceId = match.params.id;
    const [device, setDevice] = useState<Device | null>(null);
    const [loading, setLoading] = useState<boolean>(true);
    const [error, setError] = useState<string | null>(null);
    const [refresh, setRefresh] = useState(0);

    useEffect(() => {
        let active = true;
        const fetchDeviceDetails = async () => {
            setLoading(true);
            setError(null);
            setDevice(null);
            try {
                const deviceData = await getDeviceDetails(deviceId);
                if (active) setDevice(deviceData);
            } catch (err) {
                if (active) setError(err instanceof Error ? err.message : 'Failed to fetch device details.');
            } finally {
                if (active) setLoading(false);
            }
        };

        fetchDeviceDetails();
        return () => { active = false; };
    }, [deviceId, refresh]);

    if (loading) {
        return <CircularProgress />;
    }

    if (error) {
        return <Alert severity="error" action={<Button onClick={() => setRefresh(value => value + 1)}>Retry</Button>}>{error}</Alert>;
    }

    if (!device) {
        return <Typography>No device found.</Typography>;
    }

    return (
        <Card>
            <CardContent>
                <Typography variant="h5">{device.name}</Typography>
                <Typography variant="body1">Compliance Status: {device.complianceStatus}</Typography>
                <Typography variant="body1">Last Check-in: {device.lastCheckIn}</Typography>
                <Button onClick={() => setRefresh(value => value + 1)}>Refresh details</Button>
                <DeviceActions key={device.id} device={device} />
            </CardContent>
        </Card>
    );
};

export default DeviceDetails;