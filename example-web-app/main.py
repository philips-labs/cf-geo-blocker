#!/usr/bin/env python3
from flask import Flask, render_template, request
name = "example-web-app"
app = Flask(name)
@app.route('/')
def main():
    return render_template("index.html.tmpl", headers=request.headers, name=name)
