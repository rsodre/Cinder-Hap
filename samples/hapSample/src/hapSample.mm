#include "cinder/app/AppBasic.h"
#include "cinder/Surface.h"
#include "cinder/gl/Texture.h"
#include "cinder/qtime/QuickTime.h"
#include "cinder/Text.h"
#include "cinder/Utilities.h"
#include "cinder/ImageIo.h"
#include "MovieGlHap.h"

using namespace ci;
using namespace ci::app;
using namespace std;

template <typename T> string tostr(const T& t, int p) { ostringstream os; os<<std::setprecision(p)<<std::fixed<<t; return os.str(); }

class QuickTimeSampleApp : public AppBasic {
 public:
	void setup();

	void keyDown( KeyEvent event );
	void fileDrop( FileDropEvent event );

	void update();
	void draw();

	void loadMovieFile( const fs::path &path );

	gl::Texture			mFrameTexture, mInfoTexture;
	qtime::MovieGlHap	mMovie;
};

void QuickTimeSampleApp::setup()
{
	this->setFrameRate(60);
	this->setFpsSampleInterval(0.25);
	fs::path moviePath = getOpenFilePath();
	if( ! moviePath.empty() )
		loadMovieFile( moviePath );
}

void QuickTimeSampleApp::keyDown( KeyEvent event )
{
	if( event.getChar() == 'f' ) {
		setFullScreen( ! isFullScreen() );
	}
	else if( event.getChar() == 'o' ) {
		fs::path moviePath = getOpenFilePath();
		if( ! moviePath.empty() )
			loadMovieFile( moviePath );
	}
}

void QuickTimeSampleApp::loadMovieFile( const fs::path &moviePath )
{
	try {
		// load up the movie, set it to loop, and begin playing
		mMovie = qtime::MovieGlHap( moviePath );
		//mMovie.setAsRect();
		mMovie.setLoop();
		mMovie.play();
		
		// create a texture for showing some info about the movie
		TextLayout infoText;
		infoText.clear( ColorA( 0.2f, 0.2f, 0.2f, 0.5f ) );
		infoText.setColor( Color::white() );
		infoText.addCenteredLine( moviePath.filename().string() );
		infoText.addLine( toString( mMovie.getWidth() ) + " x " + toString( mMovie.getHeight() ) + " pixels" );
		infoText.addLine( toString( mMovie.getDuration() ) + " seconds" );
		infoText.addLine( toString( mMovie.getNumFrames() ) + " frames" );
		infoText.addLine( toString( mMovie.getFramerate() ) + " fps" );
		infoText.addLine( "Hap? " + std::string( mMovie.isHap() ? "Yes!" : "No." ) );
		infoText.setBorder( 4, 2 );
		mInfoTexture = gl::Texture( infoText.render( true ) );
	}
	catch( ... ) {
		console() << "Unable to load the movie." << std::endl;
		mInfoTexture.reset();
	}

	mFrameTexture.reset();
}

void QuickTimeSampleApp::fileDrop( FileDropEvent event )
{
	loadMovieFile( event.getFile( 0 ) );
}

void QuickTimeSampleApp::update()
{
	if (mMovie)
		mFrameTexture = mMovie.getTexture();
}

void QuickTimeSampleApp::draw()
{
	gl::clear( Color::white() );
	gl::enableAlphaBlending();
	
	// draw grid
	Vec2f sz = getWindowSize() / Vec2f(8,6);
	gl::color( Color::gray(0.8));
	for (int x = 0 ; x < 8 ; x++ )
		for (int y = (x%2?0:1) ; y < 6 ; y+=2 )
			 gl::drawSolidRect( Rectf(0,0,sz.x,sz.y) + sz * Vec2f(x,y) );

	// draw movie
	if( mFrameTexture ) {
		Rectf centeredRect = Rectf( mFrameTexture.getCleanBounds() ).getCenteredFit( getWindowBounds(), true );
		gl::color( Color::gray(0.2));
		gl::drawStrokedRect( centeredRect );
		gl::color( Color::white() );
		gl::draw( mFrameTexture, centeredRect  );
	}

	// draw info
	if( mInfoTexture ) {
		glDisable( GL_TEXTURE_RECTANGLE_ARB );
		gl::draw( mInfoTexture, Vec2f( 20, getWindowHeight() - 20 - mInfoTexture.getHeight() ) );
	}
	
	// draw fps
	TextLayout infoFps;
	infoFps.clear( ColorA( 0.2f, 0.2f, 0.2f, 0.5f ) );
	infoFps.setColor( Color::white() );
	infoFps.addLine( "Movie Framerate: " + tostr( mMovie.getPlaybackFramerate(), 1 ) );
	infoFps.addLine( "App Framerate: " + tostr( this->getAverageFps(), 1 ) );
	infoFps.setBorder( 4, 2 );
	gl::draw( gl::Texture( infoFps.render( true ) ), Vec2f( 20, 20 ) );
}

CINDER_APP_BASIC( QuickTimeSampleApp, RendererGl(0) );
