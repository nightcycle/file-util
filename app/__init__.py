from flask import Flask, request, jsonify
import os
import base64
import subprocess
import sys

app = Flask(__name__)

@app.route('/', methods=['GET', 'POST'])
def proxy_server():
	operation = request.args.get('operation')
	if operation == 'run':
		try:
			command = request.data.decode('utf-8')
			result = subprocess.run(command, shell=True, capture_output=True, text=True)
			output = result.stdout
			err = result.stderr
			if err:
				print("stderr", err)
			return base64.b64encode(output.encode()), 200
		except Exception as e:
			return str(e), 500
	else:


		file_path = os.path.join(os.getcwd(), request.args.get('path'))
		if operation == 'list':
			try:
				files = os.listdir(file_path)
				base64_files = [base64.b64encode(f.encode()).decode() for f in files]
				return jsonify(base64_files), 200
			except Exception as e:
				return str(e), 500
		# print(f"file_path: {file_path}")
		elif operation == 'mkdirs':
			try:
				os.makedirs(file_path)
				return '', 200
			except Exception as e:
				return str(e), 500
		elif operation == 'exists':
			try:
				if os.path.exists(file_path):
					return "true", 200
				else:
					return "false", 200
			except Exception as e:

				return str(e.args), 500
		elif operation == 'abspath':
			try:
				return base64.b64encode(os.path.abspath(file_path)).decode('utf-8'), 200
			except Exception as e:
				return str(e), 500
		elif operation == 'read':
			try:
				with open(file_path, 'rb') as f:
					return base64.b64encode(f.read()).decode('utf-8'), 200
			except Exception as e:
				return str(e), 500

		elif operation == 'remove':
			try:
				os.remove(file_path)
				return "success", 200
			except Exception as e:
				return str(e), 500
		elif operation == 'write':
			index = int(request.args.get('index'))
			total = int(request.args.get('total'))

			try:
				mode = 'wb' if index == total else 'ab'

				with open(file_path, mode) as f:
					print(f"writing {file_path}")
					f.write(base64.b64decode(request.data))

				return '', 200
			except Exception as e:
				print(str(e))
				return str(e), 500

		elif operation == 'append':
			index = int(request.args.get('index'))
			total = int(request.args.get('total'))

			try:
				mode = 'ab'

				with open(file_path, mode) as f:
					print(f"appending {file_path}")
					f.write(base64.b64decode(request.data))

				return '', 200
			except Exception as e:
				print(str(e))
				return str(e), 500

		else:
			return 'Invalid operation', 400

if __name__ == '__main__' and sys.argv[1] == "run":
    app.run(port=3090)
