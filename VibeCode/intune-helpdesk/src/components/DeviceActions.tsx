import React, { useEffect, useRef, useState } from 'react';
import Alert from '@mui/material/Alert';
import Box from '@mui/material/Box';
import Button from '@mui/material/Button';
import Stack from '@mui/material/Stack';
import Typography from '@mui/material/Typography';
import Dialog from '@mui/material/Dialog';
import DialogActions from '@mui/material/DialogActions';
import DialogContent from '@mui/material/DialogContent';
import DialogTitle from '@mui/material/DialogTitle';
import TextField from '@mui/material/TextField';
import { BitLockerRecoveryKey, Device } from '../types/device';
import { getBitLockerRecoveryKey, listBitLockerRecoveryKeys, syncDevice, wipeDevice } from '../services/deviceService';

const DeviceActions: React.FC<{ device: Device }> = ({ device }) => {
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [message, setMessage] = useState<string | null>(null);
  const [keys, setKeys] = useState<BitLockerRecoveryKey[] | null>(null);
  const [revealed, setRevealed] = useState<{ id: string; value: string } | null>(null);
  const [wipeOpen, setWipeOpen] = useState(false);
  const [wipeConfirmation, setWipeConfirmation] = useState('');
  const [wipeRequested, setWipeRequested] = useState(false);
  const active = useRef(true);
  const pending = useRef(false);
  const generation = useRef(0);

  const hideKey = () => {
    generation.current += 1;
    setRevealed(null);
  };

  useEffect(() => {
    active.current = true;
    const onVisibilityChange = () => {
      if (document.hidden) hideKey();
    };
    document.addEventListener('visibilitychange', onVisibilityChange);
    return () => {
      active.current = false;
      generation.current += 1;
      document.removeEventListener('visibilitychange', onVisibilityChange);
    };
  }, []);

  useEffect(() => {
    if (!revealed) return;
    const timeout = window.setTimeout(hideKey, 60000);
    return () => window.clearTimeout(timeout);
  }, [revealed]);

  const run = async (operation: () => Promise<void>) => {
    if (pending.current) return;
    pending.current = true;
    setBusy(true);
    setError(null);
    setMessage(null);
    hideKey();
    try {
      await operation();
    } catch (err) {
      if (active.current) setError(err instanceof Error ? err.message : 'Device action failed.');
    } finally {
      pending.current = false;
      if (active.current) setBusy(false);
    }
  };

  const sync = () => run(async () => {
    await syncDevice(device.id);
    if (active.current) setMessage('Sync requested. This does not confirm completion; the device must check in. Refresh details later to check the last check-in time.');
  });

  const loadKeys = () => run(async () => {
    setKeys(null);
    const result = await listBitLockerRecoveryKeys(device.azureADDeviceId ?? '');
    if (active.current) setKeys(result);
  });

  const revealKey = (id: string) => run(async () => {
    const requestGeneration = generation.current;
    const value = await getBitLockerRecoveryKey(id);
    if (active.current && requestGeneration === generation.current && !document.hidden) {
      setRevealed({ id, value });
    } else if (active.current) {
      setMessage('Recovery password hidden because the tab lost visibility. Select Reveal recovery key again when ready.');
    }
  });

  const windowsDevice = device.operatingSystem?.toLowerCase() === 'windows';
  const confirmationTarget = device.name || device.id;

  const closeWipe = () => {
    setWipeOpen(false);
    setWipeConfirmation('');
  };

  const confirmWipe = () => {
    if (pending.current || wipeRequested || !windowsDevice || wipeConfirmation !== confirmationTarget) return;
    closeWipe();
    return run(async () => {
      await wipeDevice(device.id);
      if (active.current) {
        setWipeRequested(true);
        setMessage('Wipe requested. This does not confirm completion. The device will process the destructive reset when it receives the command; check its status in Intune.');
      }
    });
  };

  return (
    <Box sx={{ mt: 3 }}>
      <Typography variant="h6" component="h2">Device actions</Typography>
      <Stack direction={{ xs: 'column', sm: 'row' }} spacing={2} sx={{ my: 2 }}>
        <Button variant="contained" disabled={busy} onClick={sync}>Sync device</Button>
        <Button variant="outlined" disabled={busy || !windowsDevice || !device.azureADDeviceId} onClick={loadKeys}>
          Get BitLocker recovery keys
        </Button>
        <Button color="error" variant="outlined" disabled={busy || wipeRequested || !windowsDevice} onClick={() => {
          hideKey();
          setWipeConfirmation('');
          setWipeOpen(true);
        }}>Wipe device</Button>
      </Stack>
      <Typography variant="body2" sx={{ mb: 2 }}>
        BitLocker recovery requires a Windows device with an Entra device ID. Startup PINs cannot be retrieved.
      </Typography>
      <Typography variant="body2" sx={{ mb: 2 }}>
        Wipe is currently supported here for Windows devices only. It requests a factory reset without retaining user or enrollment data.
      </Typography>
      {wipeRequested && <Alert severity="warning">A wipe has already been requested for this device in this session.</Alert>}
      <Dialog open={wipeOpen} onClose={closeWipe} aria-labelledby="wipe-title" aria-describedby="wipe-warning">
        <DialogTitle id="wipe-title">Confirm device wipe</DialogTitle>
        <DialogContent>
          <Typography id="wipe-warning" sx={{ mb: 2 }}>
            This destructive action requests a factory reset of {confirmationTarget}, removing user data and enrollment data.
            It cannot be undone by this app. Verify the device and ensure required data is backed up.
          </Typography>
          <Typography>Intune device ID: {device.id}</Typography>
          <Typography sx={{ my: 2 }}>Type exactly "{confirmationTarget}" to confirm.</Typography>
          <TextField
            autoFocus
            fullWidth
            label={device.name ? 'Device name confirmation' : 'Device ID confirmation'}
            value={wipeConfirmation}
            onChange={event => setWipeConfirmation(event.target.value)}
            autoComplete="off"
          />
        </DialogContent>
        <DialogActions>
          <Button onClick={closeWipe}>Cancel</Button>
          <Button color="error" variant="contained"
            disabled={busy || wipeRequested || wipeConfirmation !== confirmationTarget}
            onClick={confirmWipe}>Permanently wipe device</Button>
        </DialogActions>
      </Dialog>
      {busy && <Typography role="status">Processing device action...</Typography>}
      {error && <Alert severity="error">{error}</Alert>}
      {message && <Alert severity="success">{message}</Alert>}
      {keys !== null && (
        <Box sx={{ mt: 2 }}>
          <Alert severity="warning">Recovery passwords are sensitive. Reveal only the key ID matching the recovery screen. Reveal is audited by Microsoft Entra; the password hides after 60 seconds or when this tab is hidden.</Alert>
          {keys.length === 0 && <Alert severity="info">No escrowed BitLocker recovery keys were found for this device.</Alert>}
          {keys.map(key => (
            <Box key={key.id} sx={{ mt: 2 }}>
              <Typography>Key ID: {key.id}</Typography>
              <Typography>Volume: {key.volumeType} | Created: {key.createdDateTime}</Typography>
              {revealed?.id === key.id ? (
                <>
                  <Typography component="p" sx={{ fontFamily: 'monospace', overflowWrap: 'anywhere' }}>
                    {revealed.value}
                  </Typography>
                  <Button onClick={hideKey}>Hide recovery key</Button>
                </>
              ) : (
                <Button disabled={busy} onClick={() => revealKey(key.id)}>Reveal recovery key {key.id}</Button>
              )}
            </Box>
          ))}
        </Box>
      )}
    </Box>
  );
};

export default DeviceActions;
