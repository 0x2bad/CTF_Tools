#!/usr/bin/env python3
import argparse, sys, base64, json
import paho.mqtt.client as mqtt


def on_connect(client, userdata, flags, rc):
    if rc == 0:
        print("Connected to MQTT broker")
        if args.topics:
            for topic in args.topics:
                client.subscribe(topic)
        else:
            client.subscribe("#")
    else:
        print(
            f"Connection to MQTT broker failed with result code {rc}: {mqtt.connack_string(rc)}")
        sys.exit()


def on_disconnect(client, userdata, rc):
    if rc == mqtt.MQTT_ERR_SUCCESS:
        print("Disconnected from MQTT broker")
    else:
        print(
            f"Unexpected disconnection from MQTT broker with result code {rc}: {mqtt.error_string(rc)}")
        sys.exit()


def on_message(client, userdata, message):
    payload_str = message.payload.decode('utf-8')
    if args.base64 and is_base64(payload_str):
        payload_str = base64.b64decode(payload_str).decode('utf-8')
    if args.pretty_json and is_json(payload_str):
        payload_str = json.dumps(json.loads(payload_str), indent=4)
    print(f"\nTopic:\t{message.topic}\n{payload_str}")


def is_base64(s):
    try:
        return base64.b64encode(base64.b64decode(s)) == s.encode()
    except Exception:
        return False


def is_json(s):
    try:
        json.loads(s)
        return True
    except ValueError:
        return False


def main():
    global args
    parser = argparse.ArgumentParser()
    parser.add_argument("broker_ip", help="MQTT broker IP address")
    parser.add_argument("-p", "--port", type=int, default=1883, help="MQTT broker port (default 1883)")
    parser.add_argument("-t", "--ttl", type=int, default=60, help="MQTT client TTL in seconds (default 60)")
    parser.add_argument("-T", "--topics", nargs="+", help="MQTT topics to subscribe to (default all topics)")
    parser.add_argument("-b", "--base64", action="store_true", help="Try to decode base64 payloads")
    parser.add_argument("-j", "--pretty-json", action="store_true", help="Try to pretty-print JSON payloads")
    args = parser.parse_args()

    client = mqtt.Client()
    client.on_connect = on_connect
    client.on_disconnect = on_disconnect
    client.on_message = on_message

    try:
        client.connect(args.broker_ip, args.port, args.ttl)
    except ConnectionRefusedError:
        print(f"Connection to MQTT broker at {args.broker_ip}:{args.port} refused")
        sys.exit()

    try:
        client.loop_forever()
    except KeyboardInterrupt:
        print("User interrupted")
    finally:
        client.disconnect()


if __name__ == "__main__":
    main()
