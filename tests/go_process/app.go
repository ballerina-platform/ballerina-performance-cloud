package main

import (
	"bytes"
	"log"
	"net/http"
	"strconv"
)

func FibonacciLoop(n int) int {
	f := make([]int, n+1, n+2)
	if n < 2 {
		f = f[0:2]
	}
	f[0] = 0
	f[1] = 1
	for i := 2; i <= n; i++ {
		f[i] = f[i-1] + f[i-2]
	}
	return f[n]
}

type server struct{}

func (s *server) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	var buffer bytes.Buffer
	for i := 0; i <= 800; i++ {
		buffer.WriteString(strconv.Itoa(FibonacciLoop(i)) + " ")
	}
	w.Write([]byte(buffer.String()))
}

func main() {
	s := &server{}
	http.Handle("/", s)
	log.Fatal(http.ListenAndServe(":8080", nil))
}
