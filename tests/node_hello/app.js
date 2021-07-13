var express = require('express');
var app = express();

app.use(express.urlencoded({
    extended: true
  }));

app.use(express.json());

app.get('/hello', function (req, res) {
   res.send({msg : "Hello world"});
})

var server = app.listen(9090, function () {
   var host = server.address().address
   var port = server.address().port
   
   console.log("Example app listening at http://%s:%s", host, port)
})