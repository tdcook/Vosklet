# Overview
- A speech recognizer built on Vosk that can be run on the browser, inspired by [vosk-browser](https://github.com/ccoreilly/vosk-browser), but built from scratch and no code taken!
- Designed with basic/nothrow exception safety
- See the *examples* folder for examples on using the API.
- See the *devel* folder for the newest build (not guaranteed to work) and the JS build script

# Compared to vosk-browser
- Support multiple models
- Has models' storage path management
- Has models' ID management (for model updates)
- Has smaller JS size (>3.1MB vs 1.4MB gzipped)
- All related files (pthread worker, audio worklet processor,...) are merged
- Has Faster processing time
- Has shorter from-scratch build time
- Has most Vosk functions exposed

# Basic usage (microphone recognition)
- Result are logged to the console.
```
<!DOCTYPE html>
<html>
  <head>
    <script src="https://cdn.jsdelivr.net/gh/msqr1/Vosklet@1.0.0/Vosklet.js" async defer></script>
    <script>
      async function start() {
        // Make sure sample rate matches that in the training data
        let ctx = new AudioContext({sampleRate : 16000})
        // Setup mic with correct sample rate
        let micNode = ctx.createMediaStreamSource(await navigator.mediaDevices.getUserMedia({
          video: false,
          audio: {
            echoCancellation: true,
            noiseSuppression: true,
            channelCount: 1,
            sampleRate: 16000
          },
        }))
        // Load Vosklet module, model and recognizer
        let module = await loadVosklet()
        let model = await module.createModel("en-model.tgz","model","ID")
        let recognizer = await module.createRecognizer(model, 16000)
        // Listen for result and partial result
        recognizer.addEventListener("result", ev => {
          console.log("Result: ", ev.detail)
        })
        recognizer.addEventListener("partialResult", ev => {
          console.log("Partial result: ", ev.detail)
        })
        // Create a transferer node to get audio data on the main thread
        let transferer = await module.createTransferer(ctx, 128 * 150)
        // Recognize data on arrival
        transferer.port.onmessage = ev => {
          recognizer.acceptWaveform(ev.data)
        }
        micNode.connect(transferer)
      }
    </script>
    <button onclick="start()">Start</button>
  </head>
</html>
```
