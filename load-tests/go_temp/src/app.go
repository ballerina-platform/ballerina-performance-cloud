package main

import (
    "log"
    "net/http"
)

type server struct{}

func (s *server) ServeHTTP(w http.ResponseWriter, r *http.Request) {
    w.Header().Set("Content-Type", "application/json")
        w.WriteHeader(http.StatusOK)
    w.Write([]byte(`{"msg": "Hello world"}`))
}

func main() {
    s := &server{}
    http.Handle("/hello", s)
    log.Fatal(http.ListenAndServe(":8080", nil))
}
