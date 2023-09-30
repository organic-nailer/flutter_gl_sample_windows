import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_gl/flutter_gl.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const TriangleView(),
    );
  }
}

class TriangleView extends StatefulWidget {
  const TriangleView({Key? key}) : super(key: key);

  @override
  State<TriangleView> createState() => _TriangleViewState();
}

class _TriangleViewState extends State<TriangleView> {
  late Future<void> _glFuture;
  late FlutterGlPlugin _flutterGlPlugin;
  final width = 200;
  final height = 200;

  dynamic _sourceTexture;
  dynamic _vao;
  dynamic _glProgram;
  dynamic _frameBuffer;

  @override
  void initState() {
    super.initState();
    _glFuture = setupGL();
  }

  Future<void> setupGL() async {
    _flutterGlPlugin = FlutterGlPlugin();
    
    // Setup the GL context
    await _flutterGlPlugin.initialize(options: {
      "antialias": true,
      "alpha": false,
      "width": width,
      "height": height,
      "dpr": 1.0,
    });
    await _flutterGlPlugin.prepareContext();
    final gl = _flutterGlPlugin.gl;

    // Setup the Framebuffer
    _frameBuffer = gl.createFramebuffer();
    gl.bindFramebuffer(gl.FRAMEBUFFER, _frameBuffer);
    final colorTexture = gl.createTexture();
    gl.bindTexture(gl.TEXTURE_2D, colorTexture);
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, width, height, 0, gl.RGBA,
        gl.UNSIGNED_BYTE, null);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
    gl.framebufferTexture2D(
        gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, colorTexture, 0);
    _sourceTexture = colorTexture;

    // Setup the Program
    final vertexShader = gl.createShader(gl.VERTEX_SHADER);
    gl.shaderSource(vertexShader, """
#version 150
#define attribute in
#define varying out
attribute vec4 a_position;
void main() {
  gl_Position = a_position;
}
""");
    gl.compileShader(vertexShader);
    final fragmentShader = gl.createShader(gl.FRAGMENT_SHADER);
    gl.shaderSource(fragmentShader, """
#version 150
out highp vec4 pc_fragColor;
#define gl_FragColor pc_fragColor

void main() {
  gl_FragColor = vec4(1.0, 0.0, 0.0, 1.0);
}
""");
    gl.compileShader(fragmentShader);
    _glProgram = gl.createProgram();
    gl.attachShader(_glProgram, vertexShader);
    gl.attachShader(_glProgram, fragmentShader);
    gl.linkProgram(_glProgram);
    gl.deleteShader(vertexShader);
    gl.deleteShader(fragmentShader);
    gl.useProgram(_glProgram);

    // Setup the Vertex Buffer
    final vertexBuffer = gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER, vertexBuffer);
    final vertices = Float32Array.from([
      0.0, 0.5, 0.0, 1.0,
      -0.5, -0.5, 0.0, 1.0,
      0.5, -0.5, 0.0, 1.0,
    ]);
    gl.bufferData(gl.ARRAY_BUFFER, vertices.lengthInBytes, vertices, gl.STATIC_DRAW);

    final positionLocation = gl.getAttribLocation(_glProgram, "a_position");
    _vao = gl.createVertexArray();
    gl.bindVertexArray(_vao);
    {
      gl.bindBuffer(gl.ARRAY_BUFFER, vertexBuffer);
      gl.enableVertexAttribArray(positionLocation);
      gl.vertexAttribPointer(positionLocation, 4, gl.FLOAT, false, 4 * Float32List.bytesPerElement, 0);
      gl.vertexAttribPointer(positionLocation, 4, gl.FLOAT, false, 4 * Float32List.bytesPerElement, 0);
    }
    gl.bindVertexArray(0);
  }

  void render() async {
    final gl = _flutterGlPlugin.gl;
    gl.bindFramebuffer(gl.FRAMEBUFFER, _frameBuffer);
    gl.viewport(0, 0, width, height);
    gl.clearColor(0.0, 0.0, 1.0, 1.0);
    gl.clear(gl.COLOR_BUFFER_BIT);
    gl.useProgram(_glProgram);
    {
      gl.bindVertexArray(_vao); 
      {
        gl.drawArrays(gl.TRIANGLES, 0, 3);
      }
      gl.bindVertexArray(0);
    }
    gl.useProgram(0);
    gl.finish();
    await _flutterGlPlugin.updateTexture(_sourceTexture);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<void>(
        future: _glFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            final error = snapshot.error;
            if (error is Error) {
              return Center(child: Text(error.stackTrace.toString()));
            } else {
              return Center(child: Text(error.toString()));
            }
          }
          if (snapshot.connectionState == ConnectionState.done) {
            render();
            return Center(
              child: Container(
                color: Colors.amber,
                width: width.toDouble(),
                height: height.toDouble(),
                child: Texture(textureId: _flutterGlPlugin.textureId!,)
              ),
            );
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
}
