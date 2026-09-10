# Audit GPU cluster fabric for RoCE & CRC errors
import subprocess, json
servers = ["10.0.0.1", "10.0.0.2"]
for srv in servers:
    print(f"--- Auditing {srv} ---")
    subprocess.run(["ping", "-c", "5", "-M", "do", "-s", "8972", srv])
    print(f"Check CRC: ssh {srv} ethtool -S eth0 | grep crc")
payload = {"mtu": 9000, "roce_enabled": True, "pfc": True, "ecn": True}
print(json.dumps(payload, indent=2))
