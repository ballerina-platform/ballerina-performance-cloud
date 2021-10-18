from flask import Flask, request, jsonify
app = Flask(__name__)

@app.route('/hello', methods=['GET'])
def add_message():
    data = {'msg': 'Hello world'}
    return jsonify(data)

if __name__ == '__main__':
    app.run(host= '0.0.0.0',debug=False)
