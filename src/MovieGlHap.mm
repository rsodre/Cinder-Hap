/*
 *  MovieGlHap.cpp
 *
 *  Created by Roger Sodre on 14/05/10.
 *  Copyright 2010 Studio Avante. All rights reserved.
 *
 */

#include "cinder/Cinder.h"
#include "cinder/app/App.h"
#include "MovieGlHap.h"

#define IS_HAP(hapTexture)		(CVPixelBufferGetPixelFormatType(hapTexture.buffer)==kHapPixelFormatTypeRGB_DXT1)
#define IS_HAP_A(hapTexture)	(CVPixelBufferGetPixelFormatType(hapTexture.buffer)==kHapPixelFormatTypeRGBA_DXT5)
#define IS_HAP_Q(hapTexture)	(CVPixelBufferGetPixelFormatType(hapTexture.buffer)==kHapPixelFormatTypeYCoCg_DXT5)

namespace cinder { namespace qtime {

	// Playback Framerate
	uint32_t _FrameCount = 0;
	uint32_t _FpsLastSampleFrame = 0;
	double _FpsLastSampleTime = 0;
	float _AverageFps = 0;
	void updateMovieFPS( long time, void *ptr )
	{
		double now = app::getElapsedSeconds();
		if( now > _FpsLastSampleTime + app::App::get()->getFpsSampleInterval() ) {
			//calculate average Fps over sample interval
			uint32_t framesPassed = _FrameCount - _FpsLastSampleFrame;
			_AverageFps = (float)(framesPassed / (now - _FpsLastSampleTime));
			_FpsLastSampleTime = now;
			_FpsLastSampleFrame = _FrameCount;
		}
		_FrameCount++;
	}
	float MovieGlHap::getPlaybackFramerate()
	{
		return _AverageFps;
	}
	

	
	MovieGlHap::Obj::Obj()
	: MovieBase::Obj(), hapTexture(NULL)
	{
	}
	
	MovieGlHap::Obj::~Obj()
	{
		// see note on prepareForDestruction()
		prepareForDestruction();
		
		if (hapTexture)
		{
			NSLog(@"MovieGlHap :: HAP Destroy");
            [hapTexture release];
			hapTexture = NULL;
		}
	}
	
	
	MovieGlHap::MovieGlHap( const MovieLoader &loader )
	: MovieBase(), mObj( new Obj() ), mFboFrameCount( 0 ), bRectTexture( false )
	{
		MovieBase::initFromLoader( loader );
		allocateVisualContext();
	}
	
	MovieGlHap::MovieGlHap( const fs::path &path )
	: MovieBase(), mObj( new Obj() ), mFboFrameCount( 0 ), bRectTexture( false )
	{
		MovieBase::initFromPath( path );
		allocateVisualContext();
	}
	
	MovieGlHap::MovieGlHap( const void *data, size_t dataSize, const std::string &fileNameHint, const std::string &mimeTypeHint )
	: MovieBase(), mObj( new Obj() ), mFboFrameCount( 0 ), bRectTexture( false )
	{
		MovieBase::initFromMemory( data, dataSize, fileNameHint, mimeTypeHint );
		allocateVisualContext();
	}
	
	MovieGlHap::MovieGlHap( DataSourceRef dataSource, const std::string mimeTypeHint )
	: MovieBase(), mObj( new Obj() ), mFboFrameCount( 0 ), bRectTexture( false )
	{
		MovieBase::initFromDataSource( dataSource, mimeTypeHint );
		allocateVisualContext();
	}

	void MovieGlHap::allocateVisualContext()
	{
		// Load HAP Movie
		if ( (bIsHap = HapQTQuickTimeMovieHasHapTrackPlayable(getObj()->mMovie)) )
		{
			// QT Visual Context attributes
			OSStatus err = noErr;
			QTVisualContextRef * visualContext = (QTVisualContextRef*)&getObj()->mVisualContext;
			CFDictionaryRef pixelBufferOptions = HapQTCreateCVPixelBufferOptionsDictionary();
			NSDictionary *visualContextOptions = [NSDictionary dictionaryWithObject:(NSDictionary *)pixelBufferOptions
																			 forKey:(NSString *)kQTVisualContextPixelBufferAttributesKey];
			CFRelease(pixelBufferOptions);
			err = QTPixelBufferContextCreate(kCFAllocatorDefault, (CFDictionaryRef)visualContextOptions, visualContext);
			if (err != noErr)
			{
				NSLog(@"HAP ERROR :: %ld, couldnt create visual context at %s", err, __func__);
				return;
			}
			// Set the new-frame callback. You could use another mechanism, such as a CVDisplayLink, instead
			//QTVisualContextSetImageAvailableCallback( *visualContext, VisualContextFrameCallback, (void*)this );
			// Set the movie's visual context
			err = SetMovieVisualContext( getObj()->mMovie, *visualContext );
			if (err != noErr)
			{
				NSLog(@"HAP ERROR :: %ld SetMovieVisualContext %s", err, __func__);
				return;
			}
			// The movie was attached to the context, we can start it now
			//this->play();
		}
		// Load non-HAP Movie
		else
		{
			CGLContextObj cglContext = app::App::get()->getRenderer()->getCglContext();
			CGLPixelFormatObj cglPixelFormat = ::CGLGetPixelFormat( cglContext );
			// Creates a new OpenGL texture context for a specified OpenGL context and pixel format
			::QTOpenGLTextureContextCreate( kCFAllocatorDefault, cglContext, cglPixelFormat, NULL, (QTVisualContextRef*)&getObj()->mVisualContext );
			::SetMovieVisualContext( getObj()->mMovie, (QTVisualContextRef)getObj()->mVisualContext );
		}
		
		// Get codec name
		for (long i = 1; i <= GetMovieTrackCount(getObj()->mMovie); i++) {
            Track track = GetMovieIndTrack(getObj()->mMovie, i);
            Media media = GetTrackMedia(track);
            OSType mediaType;
            GetMediaHandlerDescription(media, &mediaType, NULL, NULL);
            if (mediaType == VideoMediaType)
            {
                // Get the codec-type of this track
                ImageDescriptionHandle imageDescription = (ImageDescriptionHandle)NewHandle(0); // GetMediaSampleDescription will resize it
                GetMediaSampleDescription(media, 1, (SampleDescriptionHandle)imageDescription);
                OSType codecType = (*imageDescription)->cType;
                DisposeHandle((Handle)imageDescription);
                
                switch (codecType) {
                    case 'Hap1':
						mCodecName = "Hap";
                        break;
                    case 'Hap5':
						mCodecName = "HapA";
                        break;
                    case 'HapY':
						mCodecName = "HapQ";
                        break;
                    default:
						char name[5] = { (codecType>>24)&0xFF, (codecType>>16)&0xFF, (codecType>>8)&0xFF, (codecType>>0)&0xFF, '\0' };
						mCodecName = std::string(name);
						//NSLog(@"codec [%s]",mCodecName.c_str());
                        break;
                }
            }
        }


		// Set framerate callback
		this->setNewFrameCallback( updateMovieFPS, (void*)this );
	}
	
	static void CVOpenGLTextureDealloc( void *refcon )
	{
		CVOpenGLTextureRelease( (CVImageBufferRef)(refcon) );
	}
	
	void MovieGlHap::Obj::releaseFrame()
	{
		mTexture.reset();
	}
	
	void MovieGlHap::Obj::newFrame( CVImageBufferRef cvImage )
	{
		// Load HAP frame
		CFTypeID imageType = CFGetTypeID(cvImage);
		if (imageType == CVPixelBufferGetTypeID())
		{
			// We re-use a texture for uploading the DXT pixel-buffer, create it if it doesn't already exist
			if (hapTexture == nil)
			{
				CGLContextObj cglContext = app::App::get()->getRenderer()->getCglContext();
				hapTexture = [[HapPixelBufferTexture alloc] initWithContext:cglContext];
				NSLog(@"MovieGlHap :: HAP Init");
			}
			
			// Update HAP texture
			hapTexture.buffer = cvImage;
			
			// Make gl::Texture
			GLenum target = GL_TEXTURE_2D;
			GLuint name = hapTexture.textureName;
			mTexture = gl::Texture( target, name, hapTexture.textureWidth, hapTexture.textureHeight, true );
			mTexture.setCleanTexCoords( mWidth/(float)hapTexture.textureWidth, mHeight/(float)hapTexture.textureHeight );
			mTexture.setFlipped( false );
			
			// Release CVimage (hapTexture has copied it)
			CVBufferRelease(cvImage);
		}
		// Load non-HAP frame
		else //if (imageType == CVOpenGLTextureGetTypeID())
		{
			CVOpenGLTextureRef imgRef = reinterpret_cast<CVOpenGLTextureRef>( cvImage );
			GLenum target = CVOpenGLTextureGetTarget( imgRef );
			GLuint name = CVOpenGLTextureGetName( imgRef );
			bool flipped = ! CVOpenGLTextureIsFlipped( imgRef );
			mTexture = gl::Texture( target, name, mWidth, mHeight, true );
			Vec2f t0, lowerRight, t2, upperLeft;
			::CVOpenGLTextureGetCleanTexCoords( imgRef, &t0.x, &lowerRight.x, &t2.x, &upperLeft.x );
			mTexture.setCleanTexCoords( std::max( upperLeft.x, lowerRight.x ), std::max( upperLeft.y, lowerRight.y ) );
			mTexture.setFlipped( flipped );
			mTexture.setDeallocator( CVOpenGLTextureDealloc, imgRef );
		}
	}
	
	const gl::Texture MovieGlHap::getTexture()
	{
		updateFrame();
		
		mObj->lock();
		gl::Texture result = mObj->mTexture;
		// Render FBO when HAPQ or RECT
		if ( mObj->hapTexture )
		{
			// Uses Fbo if HapQ or if we want a RECT texture
			if ( IS_HAP_Q(mObj->hapTexture) || bRectTexture )
			{
				// Create FBO
				if ( ! mFbo )
				{
					bool alpha = ( IS_HAP_A(mObj->hapTexture) /*|| IS_HAP_Q(mObj->hapTexture)*/ );
					gl::Fbo::Format fmt = gl::Fbo::Format();
					fmt.setTarget( bRectTexture ? GL_TEXTURE_RECTANGLE_ARB : GL_TEXTURE_2D );
					fmt.setColorInternalFormat( alpha ? GL_RGBA8 : GL_RGB8 );
					fmt.enableDepthBuffer( false );
					//fmt.enableMipmapping();
					mFbo = gl::Fbo( mObj->mWidth, mObj->mHeight, fmt );
					mFbo.getTexture().setFlipped();
				}
				// New frame to draw?
				if (mFboFrameCount < _FrameCount && mObj->mTexture )
				{
					// push current parameters
					glPushAttrib( GL_CURRENT_BIT | GL_VIEWPORT_BIT );
					gl::pushMatrices();
					// draw FBO
					GLhandleARB shader = mObj->hapTexture.shaderProgramObject;	// returns a shader if codec is hapQ
					mFbo.bindFramebuffer();
					gl::setMatricesWindow( mFbo.getSize() );
					gl::setViewport( mFbo.getBounds() );
					gl::color( Color::white() );
					if (shader != NULL) glUseProgramObjectARB(shader);
					gl::draw( mObj->mTexture, Area( mObj->mTexture.getCleanBounds() ), mFbo.getBounds() );
					if (shader != NULL) glUseProgramObjectARB(NULL);
					mFbo.unbindFramebuffer();
					// pop current parameters
					gl::popMatrices();
					glPopAttrib();
					mFboFrameCount = _FrameCount;
				}
				result = mFbo.getTexture();
			}
		}
		mObj->unlock();
		
		return result;
	}
	

} } //namespace cinder::qtime
