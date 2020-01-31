# About

See Dockerfile and https://grpc.io/docs/quickstart/python/

```bash
python3 -m pip install grpcio-tools
pip3 install -r requirements.txt
python3 -m grpc_tools.protoc -I. --python_out=. --grpc_python_out=. ./*.proto
python3 __main__.py
```