# ECS 152A Programming Project 3 (Fall 2025)

## Congestion Control Implementation

This assignment teaches TCP congestion control algorithms through implementation. You will build sender programs that transfer files over an emulated network with variable bandwidth, latency, and packet loss.

## Quick Start

### For Students

1. **Setup** (one time): Install Docker - see [SETUP.md](SETUP.md)
2. **Assignment**: Complete the programming tasks - see [ASSIGNMENT.md](ASSIGNMENT.md)
3. **Testing**: Use the simplified test script:
   ```bash
   cd docker
   ./test_sender.sh your_sender.py
   ```
4. **Troubleshooting**: Having issues? Check [TROUBLESHOOTING.md](TROUBLESHOOTING.md)

### Quick Test Workflow

**macOS/Linux:**
```bash
cd docker

# Start the simulator (first time or if not running)
./start-simulator.sh

# Test your implementation
./test_sender.sh my_stop_and_wait.py
```

**Windows (Command Prompt/Batch):**
```batch
cd docker

# Start the simulator
start_sim.bat

# Test your implementation
test_sender.bat my_stop_and_wait.py
```

**The script will:**
- ✓ Check Docker is running
- ✓ Restart receiver to reset state
- ✓ Copy your code into container
- ✓ Run your sender
- ✓ Verify file transfer
- ✓ Show performance metrics

## What You'll Implement

Four congestion control algorithms:

1. **Stop-and-Wait** - Send one packet, wait for ACK (simplest)
2. **TCP Tahoe** - Slow start + congestion avoidance + fast retransmit
3. **TCP Reno** - Adds fast recovery to Tahoe for better performance
4. **Custom Protocol** - Design your own congestion control algorithm (optional)
## Documentation

- **[SETUP.md](SETUP.md)** - Docker installation guide for all platforms
- **[ASSIGNMENT.md](ASSIGNMENT.md)** - Complete assignment instructions and protocol specification
- **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** - Common issues and solutions

## Project Structure

```
docker/
├── start-simulator.sh      # Start the receiver and network emulator (macOS/Linux)
├── start_sim.bat           # Start the receiver and network emulator (Windows)
├── test_sender.sh          # Test your sender - Bash (macOS/Linux)
├── test_sender.bat         # Test your sender - Batch (Windows)
├── receiver.py             # Pre-built receiver (DO NOT MODIFY)
├── training_profile.sh     # Network emulation script (DO NOT MODIFY)
├── docker-script.sh        # Container startup script
├── Dockerfile              # Container configuration
└── hdd/
    ├── file.mp3            # File to transfer (~5.1 MB)
```

## Network Simulation

The emulated network cycles through 4 phases with different conditions:

| Phase | Bandwidth | Latency | Loss | Duration |
|-------|-----------|---------|------|----------|
| 1     | 50 Mbps   | 50ms    | 0.1% | 15s      |
| 2     | 10 Mbps   | 50ms    | 1.0% | 10s      |
| 3     | 30 Mbps   | 50-150ms| 0.5% | 12s      |
| 4     | 40 Mbps   | 75ms    | 0-15%| 15s      |

Your congestion control algorithm must adapt to these changing conditions.

## Important Notes

⚠️ **You are NOT supposed to make changes to any file in this repository except your own sender implementations.**

Files you should NOT modify:
- `receiver.py` - Pre-built receiver
- `training_profile.sh` - Network emulation configuration
- `docker-script.sh` - Container startup logic
- `Dockerfile` - Container setup

## Getting Help

1. Read [ASSIGNMENT.md](ASSIGNMENT.md) for detailed instructions
2. Check [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for common issues
3. Review Week 7 discussion code: [receiver.py example](https://github.com/shaoormunir/ecs152a-fall-2025/blob/main/week7/code/receiver.py)
4. Post on course discussion board
5. Attend office hours

## Additional Resources

- [TCP Congestion Control (RFC 5681)](https://datatracker.ietf.org/doc/html/rfc5681)
- [Docker Documentation](https://docs.docker.com/)

Good luck! 🚀
