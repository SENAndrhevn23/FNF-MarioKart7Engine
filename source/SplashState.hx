package;

import flixel.FlxState;
import flixel.addons.ui.FlxVideo;

class SplashState extends FlxState {
    private var splashVideo:FlxVideo;

    override public function create():Void {
        super.create();
        
        splashVideo = new FlxVideo("videos/splash.ogv");
        splashVideo.autoPlay = true;
        splashVideo.looped = false;
        splashVideo.play();

        add(splashVideo);

        // When video finishes, go to the main menu
        splashVideo.onComplete = function() {
            FlxG.switchState(new MenuState());
        }
    }
}
