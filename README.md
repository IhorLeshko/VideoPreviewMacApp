# VideoPreviewMacApp

A simple prototype macOS application that previews live video and applies image processing in real-time.

### 🚀 How to Run

1. Clone this repository:
   git clone https://github.com/IhorLeshko/VideoPreviewMacApp.git

2.	Open VideoPreviewMacApp.xcodeproj in Xcode.
3.	Build and run on a Mac (not simulator).
4.	The app will show the live camera feed with image processing effects.

### Approach & Challenges

The app uses AVFoundation to capture video frames and applies real-time image processing through CIImage and CIFilter.

One key challenge was ensuring that the same processed frame was displayed in the preview and recorded in the video output.

### Download

You can download the latest .dmg release [here](https://github.com/IhorLeshko/VideoPreviewMacApp/releases/tag/v1.0.0).
