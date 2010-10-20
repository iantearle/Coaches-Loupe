framework 'Cocoa'
require File.join(File.dirname(NSBundle.mainBundle.executablePath), 'EMKeychain')
EMGenericKeychainItem

KCATransitionFade = "fade"
KCATransitionFromLeft = "fromLeft"

class NSUserDefaults
  def []=(key, value) 
    if value.nil? 
      delete(key) 
    else 
      setObject(value, forKey:key) 
    end 
    synchronize 
  end 
  
  def [](key) 
    objectForKey(key) 
  end 
  
  def delete(key) 
    removeObjectForKey(key) 
    synchronize 
  end
end

class CoachPreferences < NSWindow
  attr_accessor :generalView, :dribbbleView, :cloudappView
  attr_accessor :dribbbleUsername, :dribbblePassword
  attr_accessor :transition

  def init
    self.initWithContentRect([0, 0, 300, 100],
                             styleMask:NSTitledWindowMask | NSClosableWindowMask,
                             backing:NSBackingStoreBuffered,
                             defer:false)
    self.delegate = self
    self.center

    # set up switch fade animation
    transition = CATransition.animation
    transition.delegate = self
    transition.type = KCATransitionFade
    transition.subtype = KCATransitionFromLeft
    transition.duration = 0.3
    self.contentView.animations = {"subviews" => transition}

    @items = {}
    @views = {}
    
    # General
    item = NSToolbarItem.alloc.initWithItemIdentifier "General"
    item.paletteLabel = "General"
    item.label = "General"
    item.toolTip = "General preference options"
    item.image = NSImage.imageNamed("NSPreferencesGeneral")
    item.target = self
    item.action = "switchViews:"
    @items["General"] = item
    NSBundle.loadNibNamed "GeneralPreferences", owner:self
    @views["General"] = @generalView

    # Dribbble
    item = NSToolbarItem.alloc.initWithItemIdentifier "Dribbble"
    item.paletteLabel = "Dribbble"
    item.label = "Dribbble"
    item.toolTip = "Dribbble account settings"
    item.image = NSImage.imageNamed("dribbble2")
    item.target = self
    item.action = "switchViews:"
    @items["Dribbble"] = item
    NSBundle.loadNibNamed "DribbblePreferences", owner:self
    @views["Dribbble"] = @dribbbleView

#    # CloudApp
#    item = NSToolbarItem.alloc.initWithItemIdentifier "CloudApp"
#    item.paletteLabel = "CloudApp"
#    item.label = "CloudApp"
#    item.toolTip = "CloudApp account settings"
#    item.image = NSImage.imageNamed("NSPreferencesGeneral")
#    item.target = self
#    item.action = "switchViews:"
#    @items["CloudApp"] = item

    @toolbar = NSToolbar.alloc.initWithIdentifier "preferencePanes"
    @toolbar.delegate = self 
    @toolbar.allowsUserCustomization = false
    @toolbar.autosavesConfiguration = false
    self.showsToolbarButton = false
    self.setToolbar @toolbar
    self.switchViews @items["General"]

    # load preferences
    @preferences = NSUserDefaults.standardUserDefaults
    @transition.selectCellAtRow(@preferences["transition"] || 0, column:0)
    # TODO: replace by keychain
    dribbbleUsername = @preferences["dribbbleUsername"]
    @dribbbleUsername.stringValue = (dribbbleUsername || "")

    if dribbbleUsername
      @dribbbleKey = EMGenericKeychainItem
        .genericKeychainItemForService("dribbble", 
                                       withUsername: dribbbleUsername)
      if @dribbbleKey
        @dribbblePassword.stringValue = @dribbbleKey.password
      end
    end

    self
  end
  
  def animationTypeChanged(sender)
    @preferences["transition"] = sender.selectedRow
  end

  def dribbblePreferencesChanged(sender)
    # read
    username = @dribbbleUsername.stringValue
    password = @dribbblePassword.stringValue
    # save
    @preferences["dribbbleUsername"] = username
    
    if @dribbbleKey && @dribbbleKey.username == username
      @dribbbleKey.password = password
    else
      # delete old
      if @dribbbleKey
        @dribbbleKey.removeFromKeychain
      end
      
      # save new
      @dribbbleKey = EMGenericKeychainItem
        .addGenericKeychainItemForService("dribbble",
                                          withUsername: username,
                                          password: password)
    end
  end

  def toolbar(toolbar, itemForItemIdentifier:itemIdentifier, willBeInsertedIntoToolbar:flag)
    @items[itemIdentifier]
  end

  def toolbarAllowedItemIdentifiers(toolbar)
    self.toolbarDefaultItemIdentifiers toolbar
  end

  def toolbarDefaultItemIdentifiers(toolbar)
    @items.keys
  end

  def toolbarSelectableItemIdentifiers(toolbar)
    @items.keys
  end

  def switchViews(item)
    sender = item.label
    self.title = sender
    view = @views[sender]
    view.setFrame self.contentView.frame

    if @currentView
      NSDisableScreenUpdates()
      self.contentView.wantsLayer = true
      self.contentView.display
      NSEnableScreenUpdates()
      NSAnimationContext.beginGrouping
      self.contentView.animator.replaceSubview @currentView, with:view
      NSAnimationContext.endGrouping
    else
      self.contentView.addSubview view
    end
    @currentView = view
    @toolbar.selectedItemIdentifier = sender
  end

  def animationDidStop(animation, finished:done)
    if done
      self.contentView.wantsLayer = false  
    end
  end

  def windowWillClose(notification)
    NSApp.delegate.window.level = NSScreenSaverWindowLevel
    NSApp.delegate.login
  end
end
