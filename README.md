Cinder-Hap
==========

CinderHap enables the [Hap](http://vdmx.vidvox.net/blog/hap) codec on [Cinder](http://github.com/cinder/Cinder).

Hap is an [open source](https://github.com/Vidvox) video codec for fast decompression on modern graphics hardware.
Usually when a movie is being played, the CPU has to decompress every frame before passing them to the graphics card (GPU).
Hap passes the compressed frames to the GPU, who does all the decompression, saving your precious CPU from this work.

Hap was developed by [Tom Butterworth](https://twitter.com/bang_noise) and commissioned by [Vidvox](http://vidvox.net/).

For general information about Hap, read the [the Hap announcement](http://vdmx.vidvox.net/blog/hap).

For technical information about Hap, see [the Hap project](http://github.com/vidvox/hap).

The Hap codec is developed for Mac OSX only, but a Windows version is in the works.

How it works
============

Cinder-Hap has a new class called **qtime::MovieGlHap** that acts just like **qtime::MovieGl**.
When a movie encoded with Hap is loaded, it will pass compressed frames to Hap.
If the movie is not encoded with Hap, everything works like **qtime::MovieGl**.

Movies encoded with Hap are much larger than common codecs used for playback, like **Photo-JPEG** and **H.264**.
So, to benefit from Hap, you will need an **SSD drive** to read your movies from.

To encode your movies with Hap, see [this tutorial](http://vdmx.vidvox.net/tutorials/using-the-hap-video-codec).

How to add Cinder-Hap to your existing project
==============================================

1. Install the [Hap QuickTime codec](https://github.com/vidvox/hap-qt-codec).
2. Download or Fork this project to your **$CINDER_PATH/blocks** folder.
3. Add all but the samples sources files to your existing Cinder Xcode project.
4. Add the shaders to your target's **Build Bundle Resources**:

		ScaledCoCgYToRGBA.frag
		ScaledCoCgYToRGBA.vert

5. Replace all your **qtime::MovieGl** classes by **qtime::MovieGlHap**.
6. Load a Hap encoded movie and enjoy extra playback smoothness.

There's a sample project called **sampleHap** you can use for reference.

Extras
======

**qtime::MovieGlHap** has some extra functionalities...

* **bool isHap()**

	Return true if the movie is using a Hap codec.

* **void setAsRect(bool b=true)**

	Hap textures are natively stored as **GL_TEXTURE_2D**, so when you call **getTexture()**, that's what you receive to maximize performance.
	To keep compatibility with **qtime::MovieGl**, which returns **GL_TEXTURE_RECTANGLE_ARB** textures, call **setAsRect()** once after you create your movie.

	Internally, Cinder-Hap draws the original 2D texture to an Rect FBO and returns it's texture.
	So it will consume a little bit more of your CPU/GPU than working with 2D textures.

	**HapQ** also uses this FBO (2D or Rect, as you wish), because it has to be rendered with the provided shader.

* **std::string & getCodecName()**

	Returns a string containing the Hap version being used by the movie (**Hap**, **HapA** or **HapQ**).
	If not Hap, returns the [FourCC](http://www.fourcc.org/codecs.php) code of the codec.

* **float getPlaybackFramerate()**

	Returns the actual playback framerate of the movie.


Open-Source
===========

This code is released under the Modified BSD License, same as [Cinder](http://libcinder.org/).

This project was originally written by [Roger Sodré](http://www.studioavante.com/), 2013.
