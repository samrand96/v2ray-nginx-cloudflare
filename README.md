# v2ray-nginx-cloudflare
Install v2ray using docker with compatibility with Cloudflare and other CDNs easily.
-------------------------------------------
The "v2ray-nginx-cloudflare" project details:

- **Project Description**: The "v2ray-nginx-cloudflare" project encompasses an architecture that facilitates the convenient installation of V2Ray, a versatile platform for inbound and outbound network communications, using Docker. Additionally, this installation is designed to smoothly integrate and function effectively in conjunction with Cloudflare and various other Content Delivery Networks (CDNs). This combination provides an efficient and secure networking solution.

- **Key Features**:
  - V2Ray Integration: Seamless incorporation of the V2Ray platform, offering a robust framework for performing network functions.
  - Docker-Based Deployment: Leveraging Docker for streamlined installation and management, ensuring ease of deployment and maintenance.
  - Cloudflare and CDN Compatibility: Enables compatibility and optimized interaction with Cloudflare and other CDNs to deliver content and enhance network security efficiently.
  
- **Project Goals**: The primary objectives of this project are to simplify the installation process of V2Ray through Docker while ensuring compatibility with Cloudflare and other CDNs. This initiative seeks to provide an accessible and efficient means to deploy V2Ray, maintaining compatibility with industry-standard CDNs for improved performance and security.

By following the detailed instructions and utilizing the associated commands, deploying the V2Ray system within a Docker environment while harmonizing with Cloudflare and other CDNs becomes a straightforward and comprehensive process.
-------------------------------------------------

To prepare your server and set up the infrastructure, follow these steps:

1. **Configure DNS**: Create an A record in your CDN to map your server's IP, ensuring the proxy option is turned off.

2. **Install Docker**: Set up Docker and Docker-compose on your server to facilitate containerization.

3. **Clone Repository**: Use the following command to clone the "v2ray-nginx-cloudflare" repository on your server:
    ```bash
    git clone https://github.com/samrandhaji/v2ray-nginx-cloudflare.git
    ```

4. **Generate UUID**: Utilize the command below to produce a UUID:
    ```bash
    cat /proc/sys/kernel/random/uuid
    ```

5. **Update Configuration**: Replace the placeholder "<UPSTREAM-UUID>" in "v2ray/config/config.json" with the generated UUID.

6. **Customize Settings**: Modify "docker-compose.yml" by replacing "YOUR_DOMAIN" with your domain/subdomain and "YOUR_EMAIL" with your email for Let's Encrypt.

7. **Launch Services**: Execute the following command to start the services in detached mode:
    ```bash
    docker-compose up -d
    ```

8. **Access Application**: Open your web browser and visit your domain/subdomain link to confirm the application is accessible.

9. **Adjust CDN Settings**: In your CDN, activate the proxy option for the record to enhance the delivery capabilities.

10. **Generate Client Configuration**: Execute the script "./vmess.py" to create the client configuration, providing a link to access the associated resources.

By following these steps and the corresponding terminal commands, you will efficiently set up the server infrastructure and associated services for your configuration.

-----------------------------
Are you script kiddy? no time to do so? easy, haha just run the code below and see the magic:

```bash
sudo bash <(curl https://raw.githubusercontent.com/samrandhaji/v2ray-nginx-cloudflare/main/easy-install.sh)
```

---------------------------

