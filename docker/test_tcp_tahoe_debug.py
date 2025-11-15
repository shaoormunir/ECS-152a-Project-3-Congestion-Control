import socket
import time

PACKET_SIZE = 1024
SEQ_ID_SIZE = 4
MESSAGE_SIZE = PACKET_SIZE - SEQ_ID_SIZE

def create_packet(seq_id, message):
    seq_bytes = int.to_bytes(seq_id, SEQ_ID_SIZE, signed=True, byteorder="big")
    return seq_bytes + message

# Quick test
with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as udp_socket:
    udp_socket.bind(("0.0.0.0", 5003))
    udp_socket.settimeout(2.0)
    
    # Send one test packet
    test_data = b"X" * MESSAGE_SIZE
    packet = create_packet(0, test_data)
    
    print(f"Sending test packet: seq_id=0, len={len(test_data)}")
    udp_socket.sendto(packet, ("localhost", 5001))
    
    try:
        ack_packet, _ = udp_socket.recvfrom(PACKET_SIZE)
        ack_seq_id = int.from_bytes(ack_packet[:SEQ_ID_SIZE], signed=True, byteorder="big")
        ack_msg = ack_packet[SEQ_ID_SIZE:].decode()
        print(f"Received ACK: seq_id={ack_seq_id}, msg='{ack_msg}'")
    except socket.timeout:
        print("TIMEOUT - No ACK received!")
