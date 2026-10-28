import React, { useState, useEffect } from 'react';
import { useHistory } from 'react-router-dom';
import { Alert, TextField, Autocomplete, Button } from '@mui/material';
import { fetchDevices } from '../services/deviceService';
import { Device } from '../types/device';

const DeviceSearch: React.FC = () => {
    const history = useHistory();
    const [devices, setDevices] = useState<Device[]>([]);
    const [selectedDevice, setSelectedDevice] = useState<Device | null>(null);
    const [error, setError] = useState<string | null>(null);
    const [loading, setLoading] = useState(true);
    const [refresh, setRefresh] = useState(0);

    useEffect(() => {
        let active = true;
        const loadDevices = async () => {
            setLoading(true);
            setError(null);
            try {
                const deviceList = await fetchDevices();
                if (active) setDevices(deviceList);
            } catch (err) {
                if (active) setError(err instanceof Error ? err.message : 'Failed to load devices.');
            } finally {
                if (active) setLoading(false);
            }
        };
        loadDevices();
        return () => { active = false; };
    }, [refresh]);

    const handleAction = () => {
        if (selectedDevice) {
            history.push(`/device/${encodeURIComponent(selectedDevice.id)}`);
        }
    };

    return (
        <div>
            {error && <Alert severity="error" action={<Button onClick={() => setRefresh(value => value + 1)}>Retry</Button>}>{error}</Alert>}
            <Autocomplete
                options={devices}
                loading={loading}
                getOptionLabel={(option) => `${option.name} (${option.id})`}
                isOptionEqualToValue={(option, value) => option.id === value.id}
                onChange={(_, value) => setSelectedDevice(value)}
                renderInput={(params) => (
                    <TextField {...params} label="Search device by name or Intune ID" variant="outlined" />
                )}
            />
            <Button
                variant="contained"
                color="primary"
                onClick={handleAction}
                disabled={!selectedDevice}
            >
                View details
            </Button>
        </div>
    );
};

export default DeviceSearch;