# Troubleshooting Guide

Common issues and their solutions for the ECS 152A Congestion Control assignment.

## Docker Issues

### Docker daemon not running

**Symptoms:**
```
Cannot connect to the Docker daemon at unix:///var/run/docker.sock
```

**Solutions:**

**macOS:**
- If using Docker Desktop: Start Docker Desktop from Applications
- If using Colima: Run `colima start`

**Linux:**
```bash
sudo systemctl start docker
sudo systemctl enable docker  # Start on boot
```

**Windows:**
- Start Docker Desktop from the Start menu
- Ensure WSL 2 is installed and enabled

### Permission denied errors (Linux)

**Symptoms:**
```
Got permission denied while trying to connect to the Docker daemon socket
```

**Solution:**
```bash
# Add your user to the docker group
sudo usermod -aG docker $USER

# Apply the new group membership
newgrp docker

# Log out and log back in for permanent effect
```

### Container not found

**Symptoms:**
```
Error: No such container: ecs152a-simulator
```

**Solution:**
```bash
# Start the simulator
cd docker
./start-simulator.sh
```

### Container exists but won't start

**Solution:**
```bash
# Remove the old container and start fresh
docker rm -f ecs152a-simulator
./start-simulator.sh
```

## Network/Connection Issues

### Port 5001 already in use

**Symptoms:**
```
Bind for 0.0.0.0:5001 failed: port is already allocated
```

**Find what's using the port:**

**macOS/Linux:**
```bash
lsof -i :5001
# or
sudo netstat -tulpn | grep 5001
```

**Windows:**
```bash
netstat -ano | findstr :5001
```

**Solutions:**
1. Kill the process using the port
2. Or stop any other simulators running: `docker stop ecs152a-simulator`

### Receiver not responding

**Symptoms:**
- Sender times out waiting for ACKs
- No response from receiver

**Diagnostic steps:**
```bash
# Check if container is running
docker ps

# Check receiver logs
docker logs ecs152a-simulator

# Restart the simulator
docker restart ecs152a-simulator
```

**Common causes:**
- Receiver hasn't started yet (wait 3-5 seconds after starting simulator)
- Firewall blocking localhost connections
- Sending to wrong port (should be 5001)

### Connection refused

**Symptoms:**
```
ConnectionRefusedError: [Errno 111] Connection refused
```

**Solutions:**
1. Ensure receiver is running: `docker ps`
2. Check you're connecting to correct address: `localhost:5001`
3. Restart the simulator: `./start-simulator.sh`

## File Transfer Issues

### File not received (file2.mp3 not created)

**Cause**: Receiver didn't write the file, usually because FIN/ACK handshake incomplete

**Check your code for:**

1. **End-of-file signal**: Send empty packet with final sequence ID
   ```python
   # After sending all data packets
   final_packet = create_packet(final_seq_id, b"")
   udp_socket.sendto(final_packet, (RECEIVER_IP, RECEIVER_PORT))
   ```

2. **Receive FIN from receiver**:
   ```python
   ack_packet, _ = udp_socket.recvfrom(PACKET_SIZE)
   ack_msg = ack_packet[SEQ_ID_SIZE:].decode()
   if ack_msg == "fin":
       # Receiver is done
   ```

3. **Send FIN/ACK to receiver**:
   ```python
   if ack_msg == "fin":
       finack_packet = create_packet(0, b"FIN/ACK")
       udp_socket.sendto(finack_packet, (RECEIVER_IP, RECEIVER_PORT))
   ```

4. **Exit properly**: Both sender and receiver must exit after FIN/ACK

### File sizes don't match

**Symptoms:**
```
Original file: 5123456 bytes
Received file: 5120000 bytes
```

**Causes & Solutions:**

1. **Incorrect sequence ID calculation**
   - Sequence IDs should be cumulative byte count, not packet number
   ```python
   # Correct
   seq_id = 0
   for chunk in chunks:
       packets.append((seq_id, chunk))
       seq_id += len(chunk)  # Increment by data size

   # Wrong
   seq_id = 0
   for chunk in chunks:
       packets.append((seq_id, chunk))
       seq_id += 1  # This is wrong!
   ```

2. **Not sending all data**
   - Check loop conditions when slicing file
   - Ensure last packet is sent even if smaller than MESSAGE_SIZE

3. **Packets not acknowledged**
   - Receiver only writes packets it receives
   - Check retransmission logic

### File corrupted (contents different)

**Symptoms:**
```
File integrity check FAILED - files are different!
```

**Causes & Solutions:**

1. **Incorrect byte ordering in sequence ID**
   ```python
   # Correct - big-endian
   seq_bytes = int.to_bytes(seq_id, 4, signed=True, byteorder="big")

   # Wrong - little-endian
   seq_bytes = int.to_bytes(seq_id, 4, signed=True, byteorder="little")
   ```

2. **Wrong packet reconstruction**
   - Ensure you're reading exactly 4 bytes for seq_id
   - Ensure remaining bytes are payload

3. **Out-of-order delivery handling**
   - Receiver expects in-order delivery
   - Retransmit missing packets, don't skip them

4. **Incorrect payload slicing**
   ```python
   # Correct
   message = file_data[offset:offset + MESSAGE_SIZE]

   # Wrong - off-by-one errors
   message = file_data[offset:offset + MESSAGE_SIZE + 1]
   ```

## Performance Issues

### Very low throughput (< 100 bytes/sec)

**Possible causes:**

1. **Timeout too high**
   - Try reducing timeout value (e.g., 1.0 → 0.5 seconds)
   ```python
   udp_socket.settimeout(0.5)  # Lower timeout
   ```

2. **Sending one packet at a time when you should send more**
   - For Tahoe/Reno, send multiple packets in congestion window
   ```python
   # Send all packets in current window
   while next_seq_num < base + cwnd and next_seq_num < total_packets:
       # send packet
       next_seq_num += 1
   ```

3. **Not handling duplicate ACKs**
   - Duplicate ACKs indicate packet loss
   - Trigger fast retransmit on 3 duplicate ACKs

### Frequent timeouts

**Solutions:**

1. **Increase timeout value**
   - Network has variable delay (50-150ms)
   - Try timeout = 1.0 to 2.0 seconds

2. **Implement adaptive timeout**
   ```python
   estimated_rtt = 0.875 * estimated_rtt + 0.125 * sample_rtt
   timeout = max(1.0, estimated_rtt * 2)
   ```

3. **Check if you're overwhelming the network**
   - Reduce initial congestion window
   - Grow window more slowly

### Window not growing (TCP Tahoe/Reno)

**Check:**

1. **Slow start implementation**
   ```python
   if cwnd < ssthresh:
       cwnd += 1  # Exponential growth
   ```

2. **Congestion avoidance**
   ```python
   else:
       cwnd += 1.0 / cwnd  # Linear growth
   ```

3. **ACKs are being received**
   - Add debug prints to verify ACKs
   ```python
   print(f"Received ACK {ack_seq_id}, cwnd={cwnd}, ssthresh={ssthresh}")
   ```

### Window too aggressive (lots of packet loss)

**Solutions:**

1. **Lower initial cwnd**
   ```python
   cwnd = 1.0  # Start conservative
   ```

2. **Reduce ssthresh on loss**
   ```python
   ssthresh = max(cwnd / 2, 1)
   ```

3. **Implement fast retransmit properly**
   - Only retransmit on 3 duplicate ACKs, not every duplicate

## Code Issues

### Timeout exceptions not handled

**Symptom:**
```python
socket.timeout: timed out
```

**Solution:**
```python
try:
    ack_packet, _ = udp_socket.recvfrom(PACKET_SIZE)
    # process ACK
except socket.timeout:
    # Handle timeout - retransmit
    next_seq_num = base  # Go back to base of window
```

### Infinite loop - program never exits

**Common causes:**

1. **Not breaking on FIN**
   ```python
   if ack_msg == "fin":
       # Send FIN/ACK
       break  # Don't forget this!
   ```

2. **Base never reaches total_packets**
   - Check ACK processing logic
   - Ensure base is incremented when packets acknowledged

3. **Waiting for ACK that will never come**
   - Set socket timeout: `udp_socket.settimeout(TIMEOUT)`

### "module not found" errors

**Symptom:**
```
ModuleNotFoundError: No module named 'xyz'
```

**Solution:**
- Only use Python standard library modules
- Available: `socket`, `time`, `math`, `struct`
- If you need `tqdm`, it's available in the container

### Metrics not printing correctly

**Ensure CSV format:**
```python
print(f"{throughput},{avg_delay},{avg_jitter},{score}")
# Not: print(f"Throughput: {throughput}...")
```

The test script looks for a line matching: `number,number,number,number`

## Testing Issues

### test_sender.sh: command not found (macOS/Linux)

**Solution:**
```bash
# Make script executable
chmod +x test_sender.sh

# Run with ./
./test_sender.sh my_sender.py
```

### Cannot run PowerShell script (Windows)

**Symptom:**
```
.\test_sender.ps1 : File cannot be loaded because running scripts is disabled on this system
```

**Solution:**
```powershell
# Allow running PowerShell scripts (run PowerShell as Administrator)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Then run the script normally
.\test_sender.ps1 my_sender.py
```

**Alternative:** Use the batch file instead:
```batch
test_sender.bat my_sender.py
```

### Path issues on Windows

**Symptom:**
```
file.mp3 not found
```

**Solution:**
- Use backslashes on Windows: `hdd\file.mp3` not `hdd/file.mp3`
- Or run scripts from the `docker` directory:
  ```batch
  cd docker
  test_sender.bat my_sender.py
  ```

### "Docker not in PATH" error

**Solution:**
```bash
# Check if Docker is installed
which docker

# If installed but not in PATH, add to PATH
export PATH="/usr/local/bin:$PATH"  # macOS/Linux

# Or restart terminal after Docker installation
```

### Script fails to copy file into container

**Cause:** Container not running

**Solution:**
```bash
# Check container status
docker ps -a

# Start container if stopped
docker start ecs152a-simulator

# Or restart simulator
./start-simulator.sh
```

## Debugging Strategies

### Add verbose logging

```python
DEBUG = True

if DEBUG:
    print(f"Sent packet {seq_id}, window [{base}:{base+cwnd}]")
    print(f"Received ACK {ack_seq_id}")
    print(f"cwnd={cwnd:.2f}, ssthresh={ssthresh}, dup_acks={duplicate_acks}")
```

### Test with smaller file first

Replace file.mp3 with a smaller test file to iterate faster:
```bash
# Create small test file
head -c 10000 file.mp3 > test_small.mp3
docker cp test_small.mp3 ecs152a-simulator:/hdd/file.mp3
```

### Check receiver logs

```bash
docker logs ecs152a-simulator
```

Shows:
- Which packets were received
- Current network phase
- Any errors from receiver

### Manual testing

Instead of using test script:
```bash
# Start simulator
./start-simulator.sh

# In another terminal, copy and run manually
docker cp my_sender.py ecs152a-simulator:/app/
docker exec ecs152a-simulator python3 /app/my_sender.py
```

### Verify packet format

```python
# Print packet contents
packet = create_packet(seq_id, message)
print(f"Packet: seq_id={seq_id}, size={len(packet)}")
print(f"  Seq bytes: {packet[:4].hex()}")
print(f"  Payload size: {len(packet[4:])}")
```

## Still Having Issues?

1. **Review ASSIGNMENT.md** - Check protocol specification
2. **Compare with discussion code** - Week 7 receiver example
3. **Post on discussion board** - Include error messages and what you've tried
4. **Office hours** - Bring specific questions and code snippets

## Quick Reference Commands

```bash
# Start simulator
./start-simulator.sh

# Test your sender
./test_sender.sh my_sender.py

# Check Docker status
docker ps

# View receiver logs
docker logs ecs152a-simulator

# Restart receiver
docker restart ecs152a-simulator

# Stop simulator
docker stop ecs152a-simulator

# Remove container completely
docker rm -f ecs152a-simulator

# Copy file from container
docker cp ecs152a-simulator:/hdd/file2.mp3 ./received.mp3

# Run commands inside container
docker exec ecs152a-simulator ls -la /hdd/
```
