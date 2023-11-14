# v2ray-nginx-cloudflare
Install v2ray using docker with compatibility with Cloudflare and other CDNs easily.
-------------------------------------------
To prepare your server and set up the infrastructure, follow these steps:

1. Configure DNS: Create an A record in your CDN to map your server's IP, ensuring the proxy option is turned off.

2. Install Docker: Set up Docker and Docker-compose on your server to facilitate containerization.

3. File Transfer: Copy the "v2ray-nginx-cdn" directory to your server.

4. Generate UUID: Utilize the command `cat /proc/sys/kernel/random/uuid` to produce a UUID.

5. Update Configuration: Replace the placeholder "<UPSTREAM-UUID>" in "v2ray/config/config.json" with the generated UUID.

6. Customize Settings: Modify "docker-compose.yml" by replacing "YOUR_DOMAIN" with your domain/subdomain and "YOUR_EMAIL" with your email for Let's Encrypt.

7. Launch Services: Execute the command `docker-compose up -d` to start the services in detached mode.

8. Access Application: Open your web browser and visit your domain/subdomain link to confirm the application is accessible.

9. Adjust CDN Settings: In your CDN, activate the proxy option for the record to enhance the delivery capabilities.

10. Generate Client Configuration: Execute the script "./vmess.py" to create the client configuration, providing a link for access to the associated resources.

By following these steps, you will efficiently set up the server infrastructure and associated services for your configuration.
