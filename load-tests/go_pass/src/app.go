package main

import (
	"bytes"
	"encoding/json"
	"io/ioutil"
	"log"
	"net/http"
	"net/http/httputil"
	"net/url"
	"os"
)

/*
	Structs
*/

type requestPayloadStruct struct {
	ProxyCondition string `json:"proxy_condition"`
}

/*
	Utilities
*/

// Get env var or default
func getEnv(key, fallback string) string {
	if value, ok := os.LookupEnv(key); ok {
		return value
	}
	return fallback
}

/*
	Getters
*/

// Get the port to listen on
func getListenAddress() string {
	port := getEnv("PORT", "8080")
	return ":" + port
}

// Log the env variables required for a reverse proxy
func logSetup() {

	log.Printf("Server will run on: %s\n", getListenAddress())
}

/*
	Reverse Proxy Logic
*/

// Serve a reverse proxy for a given url
func serveReverseProxy(url *url.URL, res http.ResponseWriter, req *http.Request, proxy *httputil.ReverseProxy) {

	// Update the headers to allow for SSL redirection
	req.URL.Host = url.Host
	req.URL.Scheme = url.Scheme
	req.Header.Set("X-Forwarded-Host", req.Header.Get("Host"))
	req.Host = url.Host

	// Note that ServeHttp is non blocking and uses a go routine under the hood
	proxy.ServeHTTP(res, req)
}

// Get a json decoder for a given requests body
func requestBodyDecoder(request *http.Request) *json.Decoder {
	// Read body to buffer
	body, err := ioutil.ReadAll(request.Body)
	if err != nil {
		log.Printf("Error reading body: %v", err)
		panic(err)
	}

	// Because go lang is a pain in the ass if you read the body then any susequent calls
	// are unable to read the body again....
	request.Body = ioutil.NopCloser(bytes.NewBuffer(body))

	return json.NewDecoder(ioutil.NopCloser(bytes.NewBuffer(body)))
}

// Parse the requests body
func parseRequestBody(request *http.Request) requestPayloadStruct {
	decoder := requestBodyDecoder(request)

	var requestPayload requestPayloadStruct
	err := decoder.Decode(&requestPayload)

	if err != nil {
		panic(err)
	}

	return requestPayload
}

// Given a request send it to the appropriate url
func handleRequestAndRedirect(res http.ResponseWriter, req *http.Request, url *url.URL, proxy *httputil.ReverseProxy) {
	_ = parseRequestBody(req)
	serveReverseProxy(url, res, req, proxy)
}

/*
	Entry
*/

func main() {
	// Log setup values
	logSetup()
	target := "http://backend:1338/hello"

	url, _ := url.Parse(target)
	proxy := httputil.NewSingleHostReverseProxy(url)

	server := &http.Server{
		Addr: getListenAddress(),
		Handler: http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			handleRequestAndRedirect(w, r, url, proxy)
		}),
	}
	log.Fatal(server.ListenAndServe())
}
