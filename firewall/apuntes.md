# Lógica de DNAT, REDIRECT, SNAT y MASQUERADE en IPTables

## 1) PREROUTING → Se usa para **DNAT** y **REDIRECT**

### ¿Por qué?
En **PREROUTING** todavía no se ha decidido el destino final del paquete.  
Por lo tanto es el momento ideal para **cambiar la IP o el puerto destino**.


### DNAT (Destination NAT)

| Cambia | Caso de uso | Ejemplo |
|-------|-------------|---------|
| **IP destino** | Redirección hacia otro servidor interno | Port forwarding |

```bash
iptables -t nat -A PREROUTING -i eth0 -p tcp --dport 80         -j DNAT --to-destination 192.168.1.100:80
```

**Explicación:**  
Se redirige el tráfico que llega al puerto 80 del firewall hacia el servidor interno `192.168.1.100`.


### REDIRECT

| Cambia | Caso de uso | Ejemplo |
|-------|-------------|---------|
| **IP destino hacia la propia máquina** | Capturar tráfico y redirigirlo localmente | Proxy transparente |

```bash
iptables -t nat -A PREROUTING -i eth0 -p tcp --dport 80         -j REDIRECT --to-ports 3128
```

**Explicación:**  
El tráfico hacia el puerto 80 es interceptado y enviado al puerto 3128 (por ejemplo, un proxy local).


## 2) POSTROUTING → Se usa para **SNAT** y **MASQUERADE**

### ¿Por qué?
En **POSTROUTING** ya se sabe por qué interfaz y hacia dónde va el paquete.  
Por tanto, aquí es donde se debe **modificar la IP origen**.


### SNAT (Source NAT)

| Cambia | Caso de uso | Requisitos |
|-------|-------------|------------|
| **IP origen** | Redes con IP pública estática | Requiere una IP fija configurada |

```bash
iptables -t nat -A POSTROUTING -o eth0 -j SNAT --to-source 80.33.12.4
```

**Explicación:**  
Los paquetes salen con la IP pública `80.33.12.4` en lugar de su IP interna.


### MASQUERADE

| Cambia | Caso de uso | Requisitos |
|-------|-------------|------------|
| **IP origen de forma automática** | Cuando la IP pública es dinámica | Interfaces con DHCP o conexiones móviles |

```bash
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
```

**Explicación:**  
El firewall sustituye automáticamente la IP origen por la IP actual de la interfaz.


## 🎯 Resumen clave

| Momento | Cadena | Acción | Qué se modifica |
|--------|--------|--------|----------------|
| Antes de decidir el destino | **PREROUTING** | **DNAT / REDIRECT** | IP destino / puerto destino |
| Justo antes de salir | **POSTROUTING** | **SNAT / MASQUERADE** | IP origen |


## 🧠 Frase para memorizar

```
DNAT/REDIRECT → ENTRAN → se toca el DESTINO → PREROUTING

SNAT/MASQUERADE → SALEN → se toca el ORIGEN → POSTROUTING
```

