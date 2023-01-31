import os
import json

def handler(event, context):
    output = os.popen("python3 align.py examples/data/lucier.mp3 examples/data/lucier.txt").read()
    return output
