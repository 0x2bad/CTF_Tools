#!/usr/bin/env python3
import argparse, base64, sys
import paho.mqtt.client as mqtt

def on_publish(client, userdata, mid):
    print(f"Message published with ID {mid}")

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("broker_ip", help="MQTT broker IP address")
    parser.add_argument("-p", "--port", type=int, default=1883, help="MQTT broker port (default 1883)")
    parser.add_argument("-t", "--topic", required=True, help="MQTT topic to publish to")
    parser.add_argument("-m", "--message", required=True, help="MQTT message to publish")
    parser.add_argument("-b", "--base64", action="store_true", help="Encode message with base64")
    args = parser.parse_args()

    client = mqtt.Client()
    client.on_publish = on_publish

    try:
        client.connect(args.broker_ip, args.port, 60)
    except ConnectionRefusedError:
        print(f"Connection to MQTT broker at {args.broker_ip}:{args.port} refused")
        sys.exit()

    message = base64.b64encode(args.message.encode('utf-8')).decode('utf-8') if args.base64 else args.message
    result, mid = client.publish(args.topic, message)

    if result == mqtt.MQTT_ERR_SUCCESS:
        print("Waiting for message to be published...")
        client.loop()
    else:
        print(f"Failed to publish message with result code {result}")
        client.disconnect()
        sys.exit()

    client.disconnect()

if __name__ == "__main__":
    main()
