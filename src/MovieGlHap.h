/*
 *  MovieGlHap.h
 *
 *  Created by Roger Sodre on 14/05/10.
 *  Copyright 2010 Studio Avante. All rights reserved.
 *
 */
#pragma once

#include "cinder/Cinder.h"
#include "cinder/qtime/Quicktime.h"
#include "cinder/gl/gl.h"
#include "cinder/gl/Fbo.h"

extern "C" {
#import "HapSupport.h"
#import "HapPixelBufferTexture.h"
}


namespace cinder { namespace qtime {
	
	class MovieGlHap : public MovieBase {
	public:
		MovieGlHap() : MovieBase() {}
		MovieGlHap( const fs::path &path );
		MovieGlHap( const class MovieLoader &loader );
		MovieGlHap( const void *data, size_t dataSize, const std::string &fileNameHint, const std::string &mimeTypeHint = "" );
		MovieGlHap( DataSourceRef dataSource, const std::string mimeTypeHint = "" );
		
		const gl::Texture	getTexture();
		
		// NEW: Hap support
		bool			isHap()						{ return bIsHap; };			// Is this movie using any HAP codec?
		void			setAsRect(bool b=true)		{ bRectTexture=b; };		// Should getTexture() return a RECT texture? If not, returns 2D
		std::string &	getCodecName()				{ return mCodecName; }		// The codec name of the loaded movie
		float			getPlaybackFramerate();									// The actual playback framerate
		
	protected:
		
		void		allocateVisualContext();

		// NEW: Hap support
		bool		bIsHap;				
		bool		bRectTexture;		
		gl::Fbo		mFbo;				// Fbo to draw hapQ and RECT textures
		uint32_t	mFboFrameCount;		// Frame count when FBO was drawn last time
		std::string	mCodecName;			

		struct Obj : public MovieBase::Obj {
			Obj();
			~Obj();
			
			virtual void		releaseFrame();
			virtual void		newFrame( CVImageBufferRef cvImage );
			
			gl::Texture			mTexture;

			// NEW: Hap support
			HapPixelBufferTexture	*hapTexture;	// used only when codec is HAP
		};
		
		std::shared_ptr<Obj>		mObj;
		virtual MovieBase::Obj*		getObj() const { return mObj.get(); }

	public:
		//@{
		//! Emulates shared_ptr-like behavior
		typedef std::shared_ptr<Obj> MovieGlHap::*unspecified_bool_type;
		operator unspecified_bool_type() const { return ( mObj.get() == 0 ) ? 0 : &MovieGlHap::mObj; }
		void reset() { mObj.reset(); }
		//@}  
	};
	

} } //namespace cinder::qtime
