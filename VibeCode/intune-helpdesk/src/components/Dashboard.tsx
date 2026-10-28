import React, { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { getDeviceStatus } from '../services/deviceService';
import { Device } from '../types/device';
import { Alert, Button, Typography, Grid, Card, CardContent } from '@mui/material';

const Dashboard: React.FC = () => {
    const [deviceStatuses, setDeviceStatuses] = useState<Device[]>([]);
    const [loading, setLoading] = useState<boolean>(true);
    const [error, setError] = useState<string | null>(null);
    const [refresh, setRefresh] = useState(0);

    useEffect(() => {
        let active = true;
        const fetchDeviceStatuses = async () => {
            setLoading(true);
            setError(null);
            try {
                const statuses = await getDeviceStatus();
                if (active) setDeviceStatuses(statuses);
            } catch (err) {
                if (active) setError(err instanceof Error ? err.message : 'Failed to fetch device statuses.');
            } finally {
                if (active) setLoading(false);
            }
        };

        fetchDeviceStatuses();
        return () => { active = false; };
    }, [refresh]);

    if (loading) {
        return <Typography variant="h6">Loading...</Typography>;
    }

    if (error) {
        return <Alert severity="error" action={<Button onClick={() => setRefresh(value => value + 1)}>Retry</Button>}>{error}</Alert>;
    }

    if (deviceStatuses.length === 0) {
        return <Alert severity="info">No Intune managed devices were returned for this account.</Alert>;
    }

    return (
        <Grid container spacing={2}>
            {deviceStatuses.map((device) => (
                <Grid item xs={12} sm={6} md={4} key={device.id}>
                    <Card>
                        <CardContent>
                            <Typography variant="h5">{device.name}</Typography>
                            <Typography color="textSecondary">Compliance Status: {device.complianceStatus}</Typography>
                            <Typography color="textSecondary">Last Check-in: {device.lastCheckIn}</Typography>
                            <Button component={Link} to={`/device/${encodeURIComponent(device.id)}`}>View details</Button>
                            {(device.alerts?.length ?? 0) > 0 && (
                                <Typography color="error">Alerts: {device.alerts?.join(', ')}</Typography>
                            )}
                        </CardContent>
                    </Card>
                </Grid>
            ))}
        </Grid>
    );
};

export default Dashboard;