const fplay = require("@lawlers/4play");
const http = require("http");

// 4play settings
var port = 3030;
var timeout = 30000;
var password = process.env.FPLAY_PASSWORD;
if(!password){ console.error("FPLAY_PASSWORD is not set"); process.exit(1); }

// ==================================================

// webserver

var global_ws = null;
const webserver_port = 3000;

var callback_q = new Map();

const server = http.createServer(async function(req, res){
	
	const parsed = new URL(req.url, "http://localhost");
	
	const url = parsed.searchParams.get("url");
	const pw = parsed.searchParams.get("pw");
	var proxy = parsed.searchParams.get("proxy");
	const url_match = parsed.searchParams.get("url_match");
	const content_match = parsed.searchParams.get("content_match");
	const fail_url_match = parsed.searchParams.get("fail_url_match");
	const fail_content_match = parsed.searchParams.get("fail_content_match");
	
	var container = parsed.searchParams.get("container");
	
	if(fplay.browser_connected === false){
				
		res.writeHead(
			400,
			{
				"Content-Type": "text/plain"
			}
		);
		
		res.end("No browser available to render the motherfucking page");
		return;
	}
	
	var errors = [];
	
	if(
		pw === null ||
		pw != password
	){
		
		errors.push("pw");
	}
	
	if(url === null){ errors.push("url"); }
	if(proxy === null){ errors.push("proxy"); }
	
	if(errors.length !== 0){
		
		res.writeHead(
			400,
			{
				"Content-Type": "text/plain"
			}
		);
		
		res.end("The following parameters are missing or invalid: " + errors.join(", "));
		return;
	}
	
	console.log("Rendering " + url);
	
	if(
		container === null ||
		await fplay.container_exists(global_ws, container) === false
	){
		
		container = await fplay.container_create(global_ws);
		
		proxy = get_proxy(proxy);
		
		// assign proxy
		if(proxy.config !== false){
			
			await fplay.container_attach_proxy(
				global_ws,
				container,
				proxy.config
			);
		}
	}else{
		
		proxy = {raw: proxy};
	}
	
	// open tab
	const newtab = await fplay.tab_open(global_ws, url, false, container);
	
	if(newtab === false){
		
		// failed to open tab
		res.writeHead(
			400,
			{
				"Content-Type": "text/plain",
				"X-Proxy": proxy.raw,
				"X-Container-ID": typeof container.id == "undefined" ? container : container.id
			}
		);
		
		res.end("Failed to open tab");
		return;
	}
		
	// callback will be handled in "web_response"
	callback_q.set(
		newtab.id,
		{
			http_res: res,
			proxy: proxy,
			container: container,
			url_match: url_match,
			content_match: content_match,
			fail_url_match: fail_url_match,
			fail_content_match: fail_content_match
		}
	);
	
	// close tab in 30 seconds
	await fplay.wait_random(15000, 35000);
	await fplay.tab_close(global_ws, newtab);
});

server.listen(webserver_port, function(){
	
	console.log("http server running");
});

function get_proxy(proxy_line){
	
	parts = proxy_line.split(":");
	// format: type:address:port:username:password
	// PHP explode(":", $ip, 5) splits into max 5 parts
	var type = parts[0];
	const address = parts[1];
	const port = parts[2];
	const username = parts[3];
	const password = parts[4];
	
	var proxy_dns = true;
	
	switch(type){
		case "raw_ip":
		case "ip":
			// no proxy, use direct connection
			return {
				config: false,
				raw: "raw_ip::::"
			}
			break;
		
		case "socks5":
			type = "socks";
			proxy_dns = false;
			break;
			
		case "socks4a":
			type = "socks4";
			break;
			
		case "socks4":
			proxy_dns = false;
			break;
			
		case "socks5_hostname":
		case "socks5h":
		case "socks5a":
			type = "socks";
			break;
		
		case "http":
		case "https":
			// do nothing
			break;
		
		default:
			// invalid proxy provided
			return {
				config: false,
				raw: "raw_ip::::"
			}
	}
	
	return {
		config: {
			type: type,
			host: address,
			port: port,
			username: username,
			password: password,
			proxyDNS: proxy_dns
		},
		raw: proxy_line
	};
}

fplay.event.on("server_ready", function(){
	
	console.log("listening on port " + port + " (timeout=" + timeout + ")");
});

fplay.event.on("browser_connect", async function(ws){
	
	global_ws = ws;
	
	const ua = await fplay.get_ua(ws);
	console.log("New browser instance connected: " + ua);
	
	await fplay.close_all_tabs(ws);
	await fplay.delete_all_containers(ws);
	
	fplay.web_response_whitelist(ws, ["main_frame"]);
	
	// clean up
	const blanktab = await fplay.close_all_tabs(ws);
	await fplay.delete_all_containers(ws);
});

fplay.event.on("web_response", async function(page){
	
	var callback_data = callback_q.get(page.id);
	
	if(typeof callback_data == "undefined"){ return; }
	
	var body = page.body.toString();
	
	var url_match = callback_data.url_match !== null ? page.url.match(new RegExp(callback_data.url_match, "i")) : null;
	var content_match = callback_data.content_match !== null ? body.match(new RegExp(callback_data.content_match, "i")) : null;
	var fail_url_match = callback_data.fail_url_match !== null ? page.url.match(new RegExp(callback_data.fail_url_match, "i")) : null;
	var fail_content_match = callback_data.fail_content_match !== null ? body.match(new RegExp(callback_data.fail_content_match, "i")) : null;
	
	// handle negative response
	if(
		(
			callback_data.fail_url_match !== null ||
			callback_data.fail_content_match !== null
		) &&
		(
			fail_url_match !== null ||
			fail_content_match !== null
		)
	){
		
		callback_data.http_res.writeHead(
			400,
			{
				"Content-Type": "text/plain",
				"X-Proxy": callback_data.proxy.raw,
				"X-Container-ID": callback_data.container.id
			}
		);
		
		callback_data.http_res.end("Reached fail state (matched fail_url_match or fail_content_match)");
		
		// cleanup browser + callback
		await fplay.tab_close(global_ws, page.id);
		await fplay.container_delete(global_ws, callback_data.container);
		callback_q.delete(page.id);
		
		return;
	}
	
	// handle positive response
	if(
		(
			callback_data.url_match === null &&
			callback_data.content_match === null
		) ||
		(
			callback_data.url_match !== null &&
			callback_data.content_match !== null &&
			url_match &&
			content_match
		) ||
		(
			callback_data.url_match === null &&
			callback_data.content_match !== null &&
			content_match
		) ||
		(
			callback_data.url_match !== null &&
			callback_data.content_match === null &&
			url_match
		)
	){
		
		callback_data.http_res.writeHead(
			200,
			{
				"Content-Type": "text/plain;charset=UTF-8",
				"X-Proxy": callback_data.proxy.raw,
				"X-Container-ID": typeof callback_data.container.id == "undefined" ? callback_data.container : callback_data.container.id
			}
		);
		
		callback_data.http_res.end(body);
		
		callback_q.delete(page.id); // cleanup callback only
		return;
	}
});

fplay.event.on("dom_load_fail", async function(page){
	
	var callback_data = callback_q.get(page.id);
	
	if(typeof callback_data == "undefined"){ return; }
	
	callback_q.delete(page.id);
	
	callback_data.http_res.writeHead(
		400,
		{
			"Content-Type": "text/plain",
			"X-Proxy": callback_data.proxy.raw,
			"X-Container-ID": typeof callback_data.container.id == "undefined" ? callback_data.container : callback_data.container.id
		}
	);
	
	callback_data.http_res.end("Network error (" + page.error + ")");
		
	// cleanup browser
	await fplay.tab_close(global_ws, page.id);
	await fplay.container_delete(global_ws, callback_data.container);
});

fplay.init(port, password, timeout);
