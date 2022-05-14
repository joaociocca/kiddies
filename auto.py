#!/usr/bin/env python3

import socket, nmap, re, pwn, sys, os, requests
from socket import AF_INET, SOCK_DGRAM
# https://xael.org/pages/python-nmap-en.html

args = sys.argv
abertas = []
cols = os.get_terminal_size().columns

if len(args) < 2:
    print("Informe, ao menos, IP para scanear")
    sys.exit(1)

ip = args[1]
# print("args: {}".format(args))
portas = args[2] if len(args) >= 3 else "1:65536"
# print("portas: {}".format(portas))
# if len(args) >= 3:
#     print("tipo: {}".format(type(args[2])))

try:
    portas = [int(args[2])]
except:
    pattern = re.compile('^[a-zA-Z0-9]+([^a-zA-Z0-9]).+')
    if (match := re.search(pattern, portas)) is not None:
        # print("match: {}".format(match))
        # print("group1: {}".format(match.group(1)))
        argumento = portas
        print("Argumento: {}".format(argumento))
        separador = match.group(1)
        print("Separador: {}".format(separador))
        if (separador := re.search(r'([:-])', argumento)) is not None:
            separador = separador.group(1)
            portas = (x for x in range(int(argumento.split(separador)[0]), int(argumento.split(separador)[1])+1))
        elif (separador := re.search(r'([,;])', argumento)) is not None:
            separador = separador.group(1)
            portas = re.split(separador, argumento)


file_log = "log_{}.log".format(ip)
f = open(file_log, "w")
f.write("host;hostname;hostname_type;protocol;port;name;state;product;extrainfo;reason;version;conf;cpe\r\n")

file_xml = "log_{}.xml".format(ip)
f = open(file_xml, "w")

for porta in portas:
    porta = int(porta)
    result = "Porta: {}".format(porta)
    # result.
    print("Porta: {}".format(porta),end='\r')
# for porta in portas:

    print("Testando {}:{}".format(ip, porta),end='\r')

    try:
        useSocket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        useSocket.settimeout(0.3)
        
        if useSocket.connect_ex((ip,porta)) == 0:
            print("Porta {} aberta".format(porta))
            abertas+=[porta]

            try:
                http_url = 'http://{}:{}'.format(ip,porta)
                print("http_url: {}".format(http_url))
                r = requests.get(http_url)
                try:
                    server = r.headers['Server']
                    print("Server: {}".format(server))
                    version = r.headers['X-Application-Version']
                    print("Version: {}".format(version))
                except:
                    print("No headers")
                try:
                    title = re.search(re.compile('.+<title>([^<]+)</title>.+'), r.text).group(1)
                    print('HTML Title: {}'.format(title))
                except:
                    print("No HTML title.")
            except:
                print('Request error.')

            try: 
                conn = pwn.remote(ip, porta, timeout=1)
                banner = conn.recvrepeat(0.3).decode()
                conn.clean()
                conn.close()
                print("Porta {} aberta.\n\tBanner recebido: {}".format(porta, banner))
                try:
                    nm = nmap.PortScanner()
                    result = nm.scan(ip,str(porta),arguments='-sV -sC')
                    name = result['scan'][ip]['tcp'][porta]['name']
                    product = result['scan'][ip]['tcp'][porta]['product']
                    version = result['scan'][ip]['tcp'][porta]['version']
                    print("Porta",porta,"aberta. >",name,"< Produto:",product,"- Versão:",version)
                    l = open(file_log, "a")
                    l.write("{}\r\n".format((nm.csv()).split('\r\n')[1]))
                    l.close()
                    j = open(file_xml, "a")
                    j.write("{}\r\n".format(result))
                    j.close()
                except:
                    print("Nmap error.")
            except KeyboardInterrupt:
                print("Exit...")
                sys.exit()
            except:
                print("Connection error.")
            finally:
                useSocket.close()
        else:
            print("Porta fechada: {}".format(porta),end='\r')

    except KeyboardInterrupt:
            print("Exit...")
            sys.exit()

    except:
        pass

if abertas:
    print("Portas abertas: {}".format(abertas))
else:
    print("Não foram identificadas portas abertas")
