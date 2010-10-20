framework 'Cocoa'

require 'Preferences'
require 'Dribbble'

# DEBUG
class CGRect
  def to_s
    "#{size.width}x#{size.height}@(#{origin.x}, #{origin.y})"
  end
end

class DribbbleButton < NSImageView
  attr_accessor :delegate

  def mouseDragged(event)
  end

  def mouseDown(event)
    frame = self.frame
    frame.origin.y -=1
    self.frame = frame
    false
  end
  def mouseUp(event)
    frame = self.frame
    frame.origin.y +=1
    self.frame = frame

    image = @delegate.shoot
    @delegate.animate image
    @delegate.dribbble image
    false
  end
end

class CoachFrame < NSView
  def drawRect(rect)
    @image = NSImage.imageNamed("frame.png") unless @image
    @image.drawAtPoint(NSZeroPoint, fromRect:NSZeroRect,
                       operation:NSCompositeSourceOver,
                       fraction:1)
  end
end

class CoachArea < NSView
  attr_accessor :delegate

  def drawRect(rect)
    if @delegate && @delegate.animation.isAnimating
      x = [0, 0, 400, 300]
      image = @delegate.animationImage
      image.drawInRect(x, fromRect:x,
                       operation:NSCompositeSourceOver,
                       fraction:1)
    else
      NSColor.clearColor.set
      NSRectFill(bounds)
    end
  end
end

class CoachWindow < NSWindow
  attr_accessor :button, :area, :spinner

  def init
    self.initWithContentRect([0, 0, 440, 340],
                             styleMask:NSBorderlessWindowMask,
                             backing:NSBackingStoreBuffered,
                             defer:false)
    self.center
    self.contentView = CoachFrame.alloc.initWithFrame(frame)

    # button
    @button = DribbbleButton.alloc.initWithFrame [415, 45, 23, 23]
    @button.image = NSImage.imageNamed "dribbble.png"
    self.contentView.addSubview @button

    # area
    @area = CoachArea.alloc.initWithFrame [11, 30, 400, 300]
    self.contentView.addSubview @area

    # spinner
    @spinner = NSProgressIndicator.alloc.initWithFrame [418, 48, 16, 16]
    @spinner.style = NSProgressIndicatorSpinningStyle
    @spinner.usesThreadedAnimation = true
    @spinner.displayedWhenStopped = false
    @spinner.controlSize = NSSmallControlSize
    self.contentView.addSubview @spinner

    self.backgroundColor = NSColor.clearColor
    self.opaque = false
    self.hasShadow = true
    self.level = NSScreenSaverWindowLevel
    self.makeKeyAndOrderFront nil

    self
  end

  def mouseDragged(event)
    currentLocation = convertBaseToScreen self.mouseLocationOutsideOfEventStream
    setFrameOrigin NSPoint.new(currentLocation.x - @initialLocation.x,
                               currentLocation.y - @initialLocation.y)
  end

  def mouseDown(event)
    @initialLocation = event.locationInWindow
  end
end

class CoachAnimation < NSAnimation
  def setCurrentProgress(progress)
    super progress
    NSApp.delegate.window.area.display
  end
end

class Coach
  attr_accessor :animation, :window, :preferences

  def applicationDidFinishLaunching(notification)
    @window = CoachWindow.new
    @window.button.delegate = self
    @window.area.delegate = self
    
    @animation = CoachAnimation.alloc
      .initWithDuration(0.5, animationCurve:NSAnimationEaseIn)
    @animation.frameRate = 20.0

    @dribbble = Dribbble.alloc.initWithDelegate self

    login
  end
  
  def applicationWillBecomeActive(notification)
    @window.level = NSScreenSaverWindowLevel
  end

  def applicationWillResignActive(notification)
    @window.level = NSNormalWindowLevel
  end

  def login
    @preferences = NSUserDefaults.standardUserDefaults
    # dribbble
    username = @preferences["dribbbleUsername"]
    if username
      key = EMGenericKeychainItem
        .genericKeychainItemForService("dribbble", withUsername: username)
      if key
        @window.spinner.startAnimation nil
        @dribbble.login(username, key.password)
      end
    end
  end
  
  def loginSucceeded
    @window.spinner.stopAnimation nil
    NSLog "dribbble login succeeded"
    @canDribbble = true
  end

  def loginFailed
    @window.spinner.stopAnimation nil
    # TODO: show warning sign
    NSLog "dribbble login failed"
    @canDribbble = false    
  end

  def createMenu
    mainMenu = NSMenu.alloc.initWithTitle ""
    appMenu = NSMenu.alloc.initWithTitle ""
    appMenu.autoenablesItems = false
    appMenu.addItemWithTitle "About Coach", action:"orderFrontStandardAboutPanel:", keyEquivalent:""
    appMenu.addItem NSMenuItem.separatorItem
    preferences = NSMenuItem.alloc.initWithTitle "Preferences \u2026", action:"preferences:", keyEquivalent:","
    preferences.target = self
    appMenu.addItem preferences
    appMenu.addItem NSMenuItem.separatorItem
    appMenu.addItemWithTitle "Quit", action:"terminate:", keyEquivalent:"q"
    appItem = NSMenuItem.alloc.initWithTitle "", action:nil, keyEquivalent:""
    appItem.setSubmenu appMenu
    mainMenu.insertItem appItem, atIndex:0
    mainMenu
  end

  def preferences(foo)
    @preferences = CoachPreferences.new
    @window.level = NSNormalWindowLevel
    @preferences.makeKeyAndOrderFront nil
    @window.orderWindow NSWindowBelow, relativeTo:@preferences.windowNumber
  end

  def shoot
    frame = NSRectToCGRect @window.frame
    frame.origin.y = NSMaxY(@window.screen.frame) - NSMaxY(@window.frame)
    frame.origin.x += 11
    frame.origin.y += 10
    frame.size.width = 400
    frame.size.height = 300
    kCGWindowListOptionOnScreenOnly = 1
    kCGWindowListOptionOnScreenBelowWindow = 4
    kCGNullWindowID = 0
    kCGWindowImageDefault = 0
    CGWindowListCreateImage(frame, kCGWindowListOptionOnScreenBelowWindow,
                            @window.windowNumber, kCGWindowImageDefault)
  end

  def animate(cgImage)
    transitions = ["CICopyMachineTransition", "CIFlashTransition"]
    transitionNumber = NSUserDefaults.standardUserDefaults["transition"] || 0
    transition = transitions[transitionNumber]

    # set up core image filter 
    @filter = CIFilter.filterWithName transition
    @filter.setDefaults
    height = CGImageGetHeight(cgImage)
    width = CGImageGetWidth(cgImage)
    extent = CIVector.vectorWithX(0, Y:0, Z:height, W:width)
    @filter.setValue extent, forKey:"inputExtent"
    if transition == "CIFlashTransition"
      center = CIVector.vectorWithX(width/2, Y:height/2)
      @filter.setValue center, forKey:"inputCenter"
    end

    ciImage = CIImage.imageWithCGImage(cgImage)
    @filter.setValue ciImage, forKey:"inputImage"
    @filter.setValue ciImage, forKey:"inputTargetImage"
    
    # start animation and force redisplay
    @animation.startAnimation
    @window.area.display
  end

  def animationImage
    @filter.setValue(NSNumber.numberWithFloat(@animation.currentValue),
                     forKey:"inputTime")
    @filter.valueForKey("outputImage")
  end

  def dribbble(image)
    bitmap = NSBitmapImageRep.alloc.initWithCGImage image
    data = bitmap.representationUsingType NSPNGFileType, properties:nil
    data.writeToFile "/tmp/dribbble-shot.png", atomically:true
    if @canDribbble
      @window.spinner.startAnimation nil
      @dribbble.upload("/tmp/dribbble-shot.png")
    end
  end

  def uploadSucceeded(url)
    @window.spinner.stopAnimation nil
    NSLog "dribbble upload succeeded"
    NSWorkspace.sharedWorkspace.openURL url
  end

  def uploadFailed
    @window.spinner.stopAnimation nil
    NSLog "dribbble upload failed"
  end
end

app = NSApplication.sharedApplication
app.delegate = Coach.new
app.mainMenu = app.delegate.createMenu
app.run
