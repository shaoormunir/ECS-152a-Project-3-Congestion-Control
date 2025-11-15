import socket
import time
import sys

PACKET_SIZE = 1024
SEQ_ID_SIZE = 4
MESSAGE_SIZE = PACKET_SIZE - SEQ_ID_SIZE
EXPECTED_SEQ_ID = 0
RECEIVED_DATA = {}


def create_acknowledgement(seq_id, message: str) -> bytes:
    return (
        int.to_bytes(seq_id, SEQ_ID_SIZE, signed=True, byteorder="big")
        + message.encode()
    )


def main():
    global EXPECTED_SEQ_ID

    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as udp_socket:
        # Bind to all interfaces for better compatibility
        udp_socket.bind(("0.0.0.0", 5001))

        # Timeout to detect stalled transfers
        udp_socket.settimeout(10.0)
        timeouts = 0
        max_consecutive_timeouts = 3

        packets_received = 0
        duplicate_packets = 0
        last_activity = time.time()

        print("Receiver running on port 5001")
        print("Waiting for data...")

        while True:
            try:
                packet, client = udp_socket.recvfrom(PACKET_SIZE)
                timeouts = 0
                last_activity = time.time()
                packets_received += 1

                seq_id_bytes, message = packet[:SEQ_ID_SIZE], packet[SEQ_ID_SIZE:]

                # Check if this is the sender's final FIN/ACK
                if message == b"FIN/ACK":
                    print(f"\nReceived FIN/ACK from sender at {client}")
                    print(f"Total packets received: {packets_received}")
                    print(f"Duplicate packets: {duplicate_packets}")
                    print(f"Unique sequences: {len(RECEIVED_DATA)}")
                    break

                # Decode sequence ID
                seq_id = int.from_bytes(seq_id_bytes, signed=True, byteorder="big")

                # Track duplicates for debugging
                if seq_id in RECEIVED_DATA:
                    duplicate_packets += 1

                # Store the data by its starting sequence number
                RECEIVED_DATA[seq_id] = message

                # Advance EXPECTED_SEQ_ID based on contiguous bytes
                old_expected = EXPECTED_SEQ_ID
                while EXPECTED_SEQ_ID in RECEIVED_DATA:
                    # If it's the terminating empty packet, don't advance past it
                    if len(RECEIVED_DATA[EXPECTED_SEQ_ID]) == 0:
                        break
                    EXPECTED_SEQ_ID += len(RECEIVED_DATA[EXPECTED_SEQ_ID])

                # Show progress periodically
                if packets_received % 100 == 0:
                    progress = (
                        (
                            EXPECTED_SEQ_ID
                            / (EXPECTED_SEQ_ID + len(RECEIVED_DATA) * MESSAGE_SIZE)
                        )
                        * 100
                        if RECEIVED_DATA
                        else 0
                    )
                    print(
                        f"Received {packets_received} packets, Expected seq: {EXPECTED_SEQ_ID}, Duplicates: {duplicate_packets}"
                    )

                # Cumulative ACK for all bytes up to EXPECTED_SEQ_ID
                ack_id = EXPECTED_SEQ_ID
                acknowledgement = create_acknowledgement(ack_id, "ack")
                udp_socket.sendto(acknowledgement, client)

                # Check if transfer is complete after advancing EXPECTED_SEQ_ID
                # This handles the case where empty packet arrives out of order
                if (
                    EXPECTED_SEQ_ID in RECEIVED_DATA
                    and len(RECEIVED_DATA[EXPECTED_SEQ_ID]) == 0
                ):
                    print(f"\n✓ Transfer complete! Expected seq: {EXPECTED_SEQ_ID}")
                    print(f"Total packets received: {packets_received}")
                    print(f"Duplicate packets: {duplicate_packets}")
                    print(f"Unique sequences: {len(RECEIVED_DATA)}")

                    # Send final ACK and FIN
                    ack = create_acknowledgement(ack_id, "ack")
                    fin = create_acknowledgement(ack_id + 3, "fin")
                    udp_socket.sendto(ack, client)
                    udp_socket.sendto(fin, client)

                    # Give sender time to receive FIN
                    time.sleep(0.5)

            except socket.timeout:
                timeouts += 1
                print(
                    f"Timeout {timeouts}/{max_consecutive_timeouts} - No packets received for 10s"
                )

                if timeouts >= max_consecutive_timeouts:
                    print(
                        f"\n⚠ No packets for {max_consecutive_timeouts * 10}s, assuming transfer failed or completed"
                    )
                    print(f"Total packets received: {packets_received}")
                    print(f"Expected sequence ID: {EXPECTED_SEQ_ID}")
                    print(f"Sequences stored: {len(RECEIVED_DATA)}")

                    # Check if we have the complete file
                    if (
                        EXPECTED_SEQ_ID in RECEIVED_DATA
                        and len(RECEIVED_DATA[EXPECTED_SEQ_ID]) == 0
                    ):
                        print("✓ Transfer appears complete (have end marker)")
                    else:
                        print("✗ Transfer incomplete (missing end marker or data)")
                    break

            except KeyboardInterrupt:
                print("\n\nReceiver interrupted by user")
                print(f"Received {packets_received} packets before interruption")
                break

            except Exception as e:
                print(f"Error receiving packet: {e}")
                continue

    # Write out the received data in order
    print("\nWriting received data to /hdd/file2.mp3...")
    try:
        with open("/hdd/file2.mp3", "wb") as f:
            bytes_written = 0
            for sid in sorted(RECEIVED_DATA.keys()):
                f.write(RECEIVED_DATA[sid])
                bytes_written += len(RECEIVED_DATA[sid])

        print(f"✓ Wrote {bytes_written:,} bytes to /hdd/file2.mp3")

        # Verify file integrity if original exists
        try:
            import os

            if os.path.exists("/hdd/file.mp3"):
                original_size = os.path.getsize("/hdd/file.mp3")
                received_size = os.path.getsize("/hdd/file2.mp3")

                if original_size == received_size:
                    print(f"✓ File size matches original: {original_size:,} bytes")

                    # Optional: Check if files are identical
                    with open("/hdd/file.mp3", "rb") as f1, open(
                        "/hdd/file2.mp3", "rb"
                    ) as f2:
                        if f1.read() == f2.read():
                            print("✓ File content matches original perfectly!")
                        else:
                            print("✗ File size matches but content differs")
                else:
                    print(
                        f"✗ File size mismatch: original={original_size:,}, received={received_size:,}"
                    )
        except Exception as e:
            print(f"Could not verify file: {e}")

    except Exception as e:
        print(f"✗ Error writing file: {e}")
        sys.exit(1)

    print("\nReceiver exited successfully")


if __name__ == "__main__":
    main()
