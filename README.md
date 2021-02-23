# Cloud Foundry GeoIP Blocking
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## Purpose
Provide the ability to block requests to a HSDP Cloud Foundry hosted application based on GeoIP leveraging Cloud Foundry Route Services.

## Prerequisites
* **MaxMind License Key**: You will need to provide a MaxMind license key in order to download the [`GeoLite2`](https://dev.maxmind.com/geoip/geoip2/geolite2/) data. While `GeoLite2` is a free service, it requires users to [create an account](https://www.maxmind.com/en/geolite2/signup) in order to obtain a license key. Once an account is created and the user is logged in, the [license key can be found under the `My Account` menu](https://www.maxmind.com/en/accounts/current/license-key).

The MaxMind account ID and license key will need to be provided when deploying on Cloud Foundry:
```yaml
...
MAXMIND_ACCOUNT_ID: 123456
MAXMIND_LICENSE_KEY: aBcDeFgHiJkLmNoP
...
```

## Implementation Steps
**1) Build and push the container to HSDP's Docker Registry**

You can build the `cf-geo-blocker` container using the [build script](./cf-geo-blocker/build.sh), located in `./cf-geo-blocker`. The build script also pushes the Docker image to HSDP's Docker Registry. You build and push the container by running the build script and entering the values when prompted.

You can copy the [dotenv template](./cf-geo-blocker/.env.tmpl), and populate it; it will then provide default values for you:
```bash
$ > cd ./cf-geo-blocker
$ > cp .env.tmpl .env
$ > vi .env # Populate the values in the template
$ > ./build.sh
...
[Mon Feb 22 13:33:15 EST 2021]; DOCKER_REGISTRY [populated-registry]:
[Mon Feb 22 13:33:17 EST 2021]; DOCKER_NAMESPACE [populated-namespace]:
[Mon Feb 22 13:33:17 EST 2021]; DOCKER_IMAGE [populated-image]:
[Mon Feb 22 13:33:18 EST 2021]; DOCKER_TAG [populated-tag]:
[Mon Feb 22 13:33:20 EST 2021]; DOCKER_USERNAME [populated-username]:
...
```

Alternatively, you can pass a `-y` flag to the build script, so you won't be prompted for values:
```bash
$ > cd ./cf-geo-blocker
$ > cp .env.tmpl .env
$ > vi .env # Populate the values in the template
$ > ./build.sh -y
...
```
**NOTE**: There is an additional Docker image in this repo, [`example-web-app`](./example-web-app/README.md). This is not required to implement this service. Is is simply included in the event a quick way of testing the feature is needed and there is not an application already deployed to bind the `cf-geo-blocker` service to.


**2) Deploy the `cf-geo-blocker` application**
There are two sample manifest files included in this repo. If you need a sample app to route services to, use [`manifest-with-webapp.yml`](./manifest-with-webapp.yml) otherwise Cloud Foundry will use [`manifest.yml`](./manifest.yml):
* If using the sample [`manifest.yml`](./manifest.yml) manifest, update the `applications[cf-geo-blocker].routes.route` property value with your expected route.
* Copy [`./vars.yml.tmpl`](./vars.yml.tmpl) to `./vars.yml`, and populate the values for the required entries:
```yaml
 ---
DOCKER_REGISTRY:
DOCKER_NAMESPACE:
DOCKER_USERNAME:
DOCKER_TAG:
MAXMIND_ACCOUNT_ID:
MAXMIND_LICENSE_KEY:
```

**NOTE**: It is recommended that you deploy the `cf-geo-blocker` application with 2G of disk allocated.

[Log in to Cloud Foundry](https://www.hsdp.io/develop/get-started-healthsuite/log-into-cloud-foundry) and push the `cf-geo-blocker` container:
```bash
$ > read -p  'CF_ENDPOINT: ' CF_ENDPOINT && export CF_ENDPOINT=$CF_ENDPOINT
$ > read -p  'CF_USERNAME: ' CF_USERNAME && export CF_USERNAME=$CF_USERNAME
$ > read -p  'CF_ORG: ' CF_ORG && export CF_ORG=$CF_ORG
$ > read -p  'CF_SPACE: ' CF_SPACE && export CF_SPACE=$CF_SPACE
$ >
$ > # CF_DOCKER_PASSWORD is required to deploy docker containers on CF
$ > read -sp 'CF_DOCKER_PASSWORD: ' CF_DOCKER_PASSWORD && export CF_DOCKER_PASSWORD=$CF_DOCKER_PASSWORD
$ >
$ > cf login "${CF_SPACE}" -u "${CF_USERNAME}" -o "${CF_ORG}" -s "${CF_SPACE}"
$ > cf push -f manifest.yml --vars-file ./vars.yml
```

**3) Create a user-provided service and bind it to the proxied application**

While still logged in to Cloud Foundry, create a [user-provided service](https://docs.cloudfoundry.org/devguide/services/user-provided.html) (CUPS) instance with the route to the `cf-geo-blocker` instance. Be certain to include `https://` as the prefix:
```bash
$ > cf cups cf-geo-blocker-cups -r https://cf-geo-blocker-route.us-east.philips-healthsuite.com
```
Next, bind the `cf-geo-blocker-cups` service instance to the targeted application:
```bash
$ > cf bind-route-service us-east.philips-healthsuite.com --hostname example-web-app cf-geo-blocker-cups
```
Now, all requests will be handled following the rules defined in the [nginx.conf](./cf-geo-blocker/nginx.conf) file from the `cf-geo-blocker` service (there are examples in the file.)

**4) Testing the Geo Blocking service**
To test this service you can push the `cf-geo-blocker` and `example-web-app` applications using [`manifest-with-webapp.yml`](./manifest-with-webapp.yml). Be sure to update the rules in the [`nginx.conf`](./cf-geo-blocker/nginx.conf) file to allow/deny requests as desired. As an example, when testing in the US, you can toggle the `yes/no` entry.
```
...
#Example 1: A implicit "Allow all", unless the country code is explicitly denied:
map $geoip2_data_country_code $allowed {
  default yes;
  #US no;
  US yes;
}
...
```
For illustrative purposes, suppose there are:
* `cf-geo-blocker` instance at: cf-geo-blocker-7b7315a8.us-east.philips-healthsuite.com
* `example-web-app` instance at: example-web-app-7b7315a8.us-east.philips-healthsuite.com

Also, suppose that the CUPS has been created and bound, e.g.:
```bash
❯ cf routes
Getting routes for org my-org / space my-space as me ...

space     host                        domain                            port   path   type   apps              service
...
my-space   example-web-app-7b7315a8   us-east.philips-healthsuite.com                        example-web-app   cf-geo-blocker-cups
$ >
```
With the US currently configured as **allowed**, let's curl example-web-app, and inspect the container's metadata:

First, notice the custom response header from nginx's http block:
```
...
### Add headers here to return to the client
add_header X-Greeting "Hello, $geoip2_data_country_name";
...
```
We can see the custom header in the response:
```bash
$ > curl -XHEAD -I example-web-app-7b7315a8.us-east.philips-healthsuite.com
...
X-Greeting: Hello, United States
...
```
We defined a custom log message in the nginx.conf that logs geoip data:
```
log_format   main '$client_ip - $remote_user [$time_local]  $status '
    '[Location]: {"continent": "$geoip2_data_continent_code", "country": "$geoip2_data_country_code", "state": "$geoip2_data_state_code", "city": "$geoip2_data_city_name", "ip": "$client_ip"} '
    '"$request" $body_bytes_sent "$http_referer" '
    '"$http_user_agent" "$http_x_forwarded_for"';
```
The results can be observed in the container's logs:

```
$ > cf logs cf-geo-blocker --recent
...
2021-02-22T14:47:16.32-0500 [APP/PROC/WEB/0] OUT 171.84.12.145 - - [22/Feb/2021:19:47:16 +0000]  200 [Location]: {"continent": "NA", "country": "US", "state": "MA", "city": "Hingham", "ip": "171.84.12.145"} "HEAD / HTTP/1.1" 0 "-" "curl/7.64.1" "171.84.12.145, 10.10.2.142, 54.164.66.34, 10.10.2.142"
...
$ >
```
To observe the headers that were passed to the application, we can open a web browser, where the web application simply dumps the headers in a table:
```bash
$ > open -a firefox -g https://example-web-app-7b7315a8.us-east.philips-healthsuite.com/
```

Next, with the US currently configured as **Denied**, let's curl example-web-app, and inspect the container's metadata. In the nginx.conf file:
```
#Example 1: An implicit "Allow all", unless the country code is explicitly denied:
map $geoip2_data_country_code $allowed {
  default yes;
  US no;
  #US yes;
  CN no;
}
```
Now, if we curl the web application, we receive a HTTP 404 status code:
```bash
$ > curl -XHEAD -I example-web-app-7b7315a8.us-east.philips-healthsuite.com
HTTP/1.1 404 Not Found
...
$ >
```
And, the reject request was logged:
```bash
$ > cf logs cf-geo-blocker --recent
...
   2021-02-22T15:00:53.17-0500 [APP/PROC/WEB/0] OUT 171.84.12.145 - - [22/Feb/2021:20:00:53 +0000]  404 [Location]: {"continent": "NA", "country": "US", "state": "MA", "city": "Hingham", "ip": "171.84.12.145"} "HEAD / HTTP/1.1" 0 "-" "curl/7.64.1" "171.84.12.145, 10.10.66.100, 54.164.66.34, 10.10.2.142"
...

```
## References
* **Cloud Foundry** [Route Services](https://docs.cloudfoundry.org/devguide/services/route-binding.html)
