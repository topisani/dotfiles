hook global BufCreate .*\.qml %{
    set-option buffer filetype qml
}

# Initialization
# ‾‾‾‾‾‾‾‾‾‾‾‾‾‾

hook global WinSetOption filetype=qml %{
    require-module qml

    set-option window static_words %opt{qml_static_words}
    set-option window comment_line "//"
    set-option window comment_block_begin "/*"
    set-option window comment_block_end "*/"

    # cleanup trailing whitespaces when exiting insert mode
    hook window ModeChange pop:insert:.* -group qml-trim-indent %{ try %{ execute-keys -draft <a-x>s^\h+$<ret>d } }
    hook window InsertChar \n -group qml-insert qml-insert-on-new-line
    hook window InsertChar \n -group qml-indent qml-indent-on-new-line
    hook window InsertChar \{ -group qml-indent qml-indent-on-opening-curly-brace
    hook window InsertChar \} -group qml-indent qml-indent-on-closing-curly-brace

    hook -once -always window WinSetOption filetype=.* %{ remove-hooks window qml-.+ }
}

hook -group qml-highlight global WinSetOption filetype=qml %{
    add-highlighter window/qml ref qml
    hook -once -always window WinSetOption filetype=.* %{ remove-highlighter window/qml }
}

provide-module qml %§

add-highlighter shared/qml regions
add-highlighter shared/qml/code default-region group
add-highlighter shared/qml/string region %{(?<!')"} %{(?<!\\)(\\\\)*"} fill string
add-highlighter shared/qml/character region %{'} %{(?<!\\)'} fill value
add-highlighter shared/qml/comment region /\* \*/ fill comment
add-highlighter shared/qml/inline_documentation region /// $ fill documentation
add-highlighter shared/qml/line_comment region // $ fill comment
add-highlighter shared/qml/code/number regex "-?\b[0-9]*\.?[0-9]+" 0:value
add-highlighter shared/qml/code/type regex "\b[A-Z]\w+\b" 0:type
add-highlighter shared/qml/code/var regex "\b[a-z]\w+\b" 0:variable

# Commands
# ‾‾‾‾‾‾‾‾

define-command -hidden qml-insert-on-new-line %[
        # copy // comments prefix and following white spaces
        try %{ execute-keys -draft <semicolon><c-s>k<a-x> s ^\h*\K/{2,}\h* <ret> y<c-o>P<esc> }
]

define-command -hidden qml-indent-on-new-line %~
    evaluate-commands -draft -itersel %=
        # preserve previous line indent
        try %{ execute-keys -draft <semicolon>K<a-&> }
        # indent after lines ending with { or (
        try %[ execute-keys -draft k<a-x> <a-k> [{(]\h*$ <ret> j<a-gt> ]
        # cleanup trailing white spaces on the previous line
        try %{ execute-keys -draft k<a-x> s \h+$ <ret>d }
        # align to opening paren of previous line
        try %{ execute-keys -draft [( <a-k> \A\([^\n]+\n[^\n]*\n?\z <ret> s \A\(\h*.|.\z <ret> '<a-;>' & }
        # indent after a switch's case/default statements
        try %[ execute-keys -draft k<a-x> <a-k> ^\h*(case|default).*:$ <ret> j<a-gt> ]
        # indent after keywords
        try %[ execute-keys -draft <semicolon><a-F>)MB <a-k> \A(if|else|while|for|try|catch)\h*\(.*\)\h*\n\h*\n?\z <ret> s \A|.\z <ret> 1<a-&>1<a-space><a-gt> ]
        # deindent closing brace(s) when after cursor
        try %[ execute-keys -draft <a-x> <a-k> ^\h*[})] <ret> gh / [})] <ret> m <a-S> 1<a-&> ]
    =
~

define-command -hidden qml-indent-on-opening-curly-brace %[
    # align indent with opening paren when { is entered on a new line after the closing paren
    try %[ execute-keys -draft -itersel h<a-F>)M <a-k> \A\(.*\)\h*\n\h*\{\z <ret> s \A|.\z <ret> 1<a-&> ]
]

define-command -hidden qml-indent-on-closing-curly-brace %[
    # align to opening curly brace when alone on a line
    try %[ execute-keys -itersel -draft <a-h><a-k>^\h+\}$<ret>hms\A|.\z<ret>1<a-&> ]
]

# Shell
# ‾‾‾‾‾
evaluate-commands %sh{
    values='false null self true arguments this'

    types='Array Boolean Date Function Number Object String RegExp
           action alias bool color date double enumeration font int list point real rect size string 
           time url variant vector2d  vector3d vector4d coordinate geocircle geopath geopolygon 
           georectangle geoshape matrix4x4 palette quaternion'

    keywords='if else switch while for do in break continue new delete instanceof typeof return
              with var let const case default try catch finally throw 
              property signal component readonly required
              abstract boolean byte char class debugger enum export extends final float goto 
              implements import interface long native package pragma private protected public short 
              static super synchronized throws transient volatile
              function
              '

    attributes='abstract final native non-sealed permits private protected public
        record sealed synchronized transient volatile'

    qtypes='Abstract3DSeries AbstractActionInput AbstractAnimation AbstractAxis AbstractAxis3D AbstractAxisInput AbstractBarSeries AbstractButton AbstractClipAnimator AbstractClipBlendNode AbstractDataProxy AbstractGraph3D AbstractInputHandler3D AbstractPhysicalDevice AbstractRayCaster AbstractSeries AbstractSkeleton AbstractTexture AbstractTextureImage Accelerometer AccelerometerReading Accessible Action ActionGroup ActionInput AdditiveClipBlend AdditiveColorGradient Address Affector Age AlphaCoverage AlphaTest Altimeter AltimeterReading AluminumAnodizedEmissiveMaterial AluminumAnodizedMaterial AluminumBrushedMaterial AluminumEmissiveMaterial AluminumMaterial AmbientLightReading AmbientLightSensor AmbientTemperatureReading AmbientTemperatureSensor AnalogAxisInput AnchorAnimation AnchorChanges AngleDirection AnimatedImage AnimatedSprite Animation AnimationController AnimationGroup Animator ApplicationWindow ApplicationWindowStyle AreaLight AreaSeries Armature AttenuationModelInverse AttenuationModelLinear Attractor Attribute Audio AudioCategory AudioEngine AudioListener AudioSample AuthenticationDialogRequest Axis AxisAccumulator AxisHelper AxisSetting 
    BackspaceKey Bar3DSeries BarCategoryAxis BarDataProxy Bars3D BarSeries BarSet BaseKey BasicTableView Behavior Binding Blend BlendedClipAnimator BlendEquation BlendEquationArguments Blending BlitFramebuffer BluetoothDiscoveryModel BluetoothService BluetoothSocket Blur bool BorderImage BorderImageMesh BoundaryRule Bounds BoxPlotSeries BoxSet BrightnessContrast BrushStrokes Buffer BufferBlit BufferCapture BufferInput BusyIndicator BusyIndicatorStyle Button ButtonAxisInput ButtonGroup ButtonStyle 
    Calendar CalendarModel CalendarStyle Camera Camera3D CameraCapabilities CameraCapture CameraExposure CameraFlash CameraFocus CameraImageProcessing CameraLens CameraRecorder CameraSelector CandlestickSeries CandlestickSet Canvas CanvasGradient CanvasImageData CanvasPixelArray Category CategoryAxis CategoryAxis3D CategoryModel CategoryRange ChangeLanguageKey ChartView CheckBox CheckBoxStyle CheckDelegate ChromaticAberration CircularGauge CircularGaugeStyle ClearBuffers ClipAnimator ClipBlendValue ClipPlane CloseEvent color ColorAnimation ColorDialog ColorDialogRequest ColorGradient ColorGradientStop Colorize ColorMask ColorMaster ColorOverlay Column ColumnLayout ComboBox ComboBoxStyle Command Compass CompassReading Component Component3D ComputeCommand ConeGeometry ConeMesh ConicalGradient Connections ContactDetail ContactDetails Container Context2D ContextMenuRequest Control coordinate CoordinateAnimation CopperMaterial CuboidGeometry CuboidMesh CullFace CullMode CumulativeDirection Custom3DItem Custom3DLabel Custom3DVolume CustomCamera CustomMaterial CustomParticle CylinderGeometry CylinderMesh 
    Date date DateTimeAxis DayOfWeekRow DebugView DefaultMaterial DelayButton DelayButtonStyle DelegateChoice DelegateChooser DelegateModel DelegateModelGroup DepthInput DepthOfFieldHQBlur DepthRange DepthTest Desaturate Dial Dialog DialogButtonBox DialStyle DiffuseMapMaterial DiffuseSpecularMapMaterial DiffuseSpecularMaterial Direction DirectionalBlur DirectionalLight DispatchCompute Displace DistanceReading DistanceSensor DistortionRipple DistortionSphere DistortionSpiral Dithering double DoubleValidator Drag DragEvent DragHandler Drawer DropArea DropShadow DwmFeatures DynamicParameter 
    EdgeDetect EditorialModel Effect EllipseShape Emboss Emitter EnterKey EnterKeyAction Entity EntityLoader enumeration EnvironmentLight EventConnection EventPoint EventTouchPoint ExclusiveGroup ExtendedAttributes ExtrudedTextGeometry ExtrudedTextMesh 
    FastBlur FileDialog FileDialogRequest FillerKey FilterKey FinalState FindTextResult FirstPersonCameraController Flickable Flip Flipable Flow FocusScope FolderDialog FolderListModel font FontDialog FontLoader FontMetrics FormValidationMessageRequest ForwardRenderer Frame FrameAction FrameGraphNode Friction FrontFace FrostedGlassMaterial FrostedGlassSinglePassMaterial FrustumCamera FrustumCulling FullScreenRequest Fxaa 
    Gamepad GamepadManager GammaAdjust Gauge GaugeStyle GaussianBlur geocircle GeocodeModel Geometry GeometryRenderer geopath geopolygon georectangle geoshape GestureEvent GlassMaterial GlassRefractiveMaterial Glow GoochMaterial Gradient GradientStop GraphicsApiFilter GraphicsInfo Gravity Grid GridGeometry GridLayout GridMesh GridView GroupBox GroupGoal Gyroscope GyroscopeReading 
    HandlerPoint HandwritingInputPanel HandwritingModeKey HBarModelMapper HBoxPlotModelMapper HCandlestickModelMapper HDRBloomTonemap HeightMapSurfaceDataProxy HideKeyboardKey HistoryState HolsterReading HolsterSensor HorizontalBarSeries HorizontalHeaderView HorizontalPercentBarSeries HorizontalStackedBarSeries Host HoverHandler HPieModelMapper HueSaturation HumidityReading HumiditySensor HXYModelMapper 
    Icon IdleInhibitManagerV1 Image ImageModel ImageParticle InnerShadow InputChord InputContext InputEngine InputHandler3D InputMethod InputModeKey InputPanel InputSequence InputSettings Instantiator int IntValidator InvokedServices IRProximityReading IRProximitySensor Item ItemDelegate ItemGrabResult ItemModelBarDataProxy ItemModelScatterDataProxy ItemModelSurfaceDataProxy ItemParticle ItemSelectionModel IviApplication IviSurface 
    JavaScriptDialogRequest Joint JumpList JumpListCategory JumpListDestination JumpListLink JumpListSeparator 
    Key KeyboardColumn KeyboardDevice KeyboardHandler KeyboardLayout KeyboardLayoutLoader KeyboardRow KeyboardStyle KeyEvent Keyframe KeyframeAnimation KeyframeGroup KeyIcon KeyNavigation KeyPanel Keys 
    Label Layer LayerFilter Layout LayoutMirroring Legend LerpClipBlend LevelAdjust LevelOfDetail LevelOfDetailBoundingSphere LevelOfDetailLoader LevelOfDetailSwitch LidReading LidSensor Light Light3D LightReading LightSensor LinearGradient LineSeries LineShape LineWidth list ListElement ListModel ListView Loader Loader3D Locale Location LoggingCategory LogicalDevice LogValueAxis LogValueAxis3DFormatter LottieAnimation 
    Magnetometer MagnetometerReading Map MapCircle MapCircleObject MapCopyrightNotice MapGestureArea MapIconObject MapItemGroup MapItemView MapObjectView MapParameter MapPinchEvent MapPolygon MapPolygonObject MapPolyline MapPolylineObject MapQuickItem MapRectangle MapRoute MapRouteObject MapType Margins MaskedBlur MaskShape Material Matrix4x4 matrix4x4 MediaPlayer mediaplayer-qml-dynamic MemoryBarrier Menu MenuBar MenuBarItem MenuBarStyle MenuItem MenuItemGroup MenuSeparator MenuStyle Mesh MessageDialog MetalRoughMaterial ModeKey Model MonthGrid MorphingAnimation MorphTarget MotionBlur MouseArea MouseDevice MouseEvent MouseHandler MultiPointHandler MultiPointTouchArea MultiSampleAntiAliasing 
    Navigator NdefFilter NdefMimeRecord NdefRecord NdefTextRecord NdefUriRecord NearField Node NodeInstantiator NoDepthMask NoDraw NoPicking NormalDiffuseMapAlphaMaterial NormalDiffuseMapMaterial NormalDiffuseSpecularMapMaterial Number NumberAnimation NumberKey 
    Object3D ObjectModel ObjectPicker OpacityAnimator OpacityMask OpenGLInfo OrbitCameraController OrientationReading OrientationSensor OrthographicCamera Overlay 
    Package Page PageIndicator palette Pane PaperArtisticMaterial PaperOfficeMaterial ParallelAnimation Parameter ParentAnimation ParentChange Particle ParticleExtruder ParticleGroup ParticlePainter ParticleSystem Pass Path PathAngleArc PathAnimation PathArc PathAttribute PathCubic PathCurve PathElement PathInterpolator PathLine PathMove PathMultiline PathPercent PathPolyline PathQuad PathSvg PathText PathView PauseAnimation PdfDocument PdfLinkModel PdfNavigationStack PdfSearchModel PdfSelection PercentBarSeries PerspectiveCamera PerVertexColorMaterial PhongAlphaMaterial PhongMaterial PickEvent PickingSettings PickLineEvent PickPointEvent PickResult PickTriangleEvent Picture PieMenu PieMenuStyle PieSeries PieSlice PinchArea PinchEvent PinchHandler Place PlaceAttribute PlaceSearchModel PlaceSearchSuggestionModel PlaneGeometry PlaneMesh PlasticStructuredRedEmissiveMaterial PlasticStructuredRedMaterial Playlist PlaylistItem PlayVariation Plugin PluginParameter point PointDirection PointerDevice PointerDeviceHandler PointerEvent PointerHandler PointerScrollEvent PointHandler PointLight PointSize PolarChartView PolygonOffset Popup Position Positioner PositionSource PressureReading PressureSensor PrincipledMaterial Product ProgressBar ProgressBarStyle PropertyAction PropertyAnimation PropertyChanges ProximityFilter ProximityReading ProximitySensor 
    QAbstractState QAbstractTransition QmlSensors QSignalTransition Qt QtMultimedia QtObject QtPositioning QtRemoteObjects quaternion QuaternionAnimation QuotaRequest 
    RadialBlur RadialGradient Radio RadioButton RadioButtonStyle RadioData RadioDelegate RangeSlider RasterMode Ratings RayCaster real rect Rectangle RectangleShape RectangularGlow RecursiveBlur RegExpValidator RegisterProtocolHandlerRequest RegularExpressionValidator RenderCapabilities RenderCapture RenderCaptureReply RenderPass RenderPassFilter RenderSettings RenderState RenderStateSet RenderStats RenderSurfaceSelector RenderTarget RenderTargetOutput RenderTargetSelector Repeater Repeater3D ReviewModel Rotation RotationAnimation RotationAnimator RotationReading RotationSensor RoundButton Route RouteLeg RouteManeuver RouteModel RouteQuery RouteSegment Row RowLayout 
    Scale ScaleAnimator Scatter Scatter3D Scatter3DSeries ScatterDataProxy ScatterSeries Scene2D Scene3D Scene3DView SceneEnvironment SceneLoader ScissorTest Screen ScreenRayCaster ScriptAction ScrollBar ScrollIndicator ScrollView ScrollViewStyle SCurveTonemap ScxmlStateMachine SeamlessCubemap SelectionListItem SelectionListModel Sensor SensorGesture SensorReading SequentialAnimation Settings SettingsStore SetUniformValue Shader ShaderEffect ShaderEffectSource ShaderImage ShaderInfo ShaderProgram ShaderProgramBuilder Shape ShapeGradient ShapePath SharedGLTexture ShellSurface ShellSurfaceItem ShiftHandler ShiftKey Shortcut SignalSpy SignalTransition SinglePointHandler size Skeleton SkeletonLoader SkyboxEntity Slider SliderStyle SmoothedAnimation SortPolicy Sound SoundEffect SoundInstance SpaceKey SphereGeometry SphereMesh SpinBox SpinBoxStyle SplineSeries SplitHandle SplitView SpotLight SpringAnimation Sprite SpriteGoal SpriteSequence Stack StackedBarSeries StackLayout StackView StackViewDelegate StandardPaths State StateChangeScript StateGroup StateMachine StateMachineLoader StatusBar StatusBarStyle StatusIndicator StatusIndicatorStyle SteelMilledConcentricMaterial StencilMask StencilOperation StencilOperationArguments StencilTest StencilTestArguments Store String string SubtreeEnabler Supplier Surface3D Surface3DSeries SurfaceDataProxy SwipeDelegate SwipeView Switch SwitchDelegate SwitchStyle SymbolModeKey SystemPalette SystemTrayIcon 
    Tab TabBar TabButton TableModel TableModelColumn TableView TableViewColumn TableViewStyle TabView TabViewStyle TapHandler TapReading TapSensor TargetDirection TaskbarButton Technique TechniqueFilter TestCase Text Text2DEntity TextArea TextAreaStyle TextEdit TextField TextFieldStyle TextInput TextMetrics Texture Texture1D Texture1DArray Texture2D Texture2DArray Texture2DMultisample Texture2DMultisampleArray Texture3D TextureBuffer TextureCubeMap TextureCubeMapArray TextureImage TextureInput TextureLoader TextureRectangle Theme3D ThemeColor ThresholdMask ThumbnailToolBar ThumbnailToolButton TiltReading TiltSensor TiltShift Timeline TimelineAnimation TimeoutTransition Timer ToggleButton ToggleButtonStyle ToolBar ToolBarStyle ToolButton ToolSeparator ToolTip TooltipRequest Torch TorusGeometry TorusMesh TouchEventSequence TouchInputHandler3D TouchPoint Trace TraceCanvas TraceInputArea TraceInputKey TraceInputKeyPanel TrailEmitter Transaction Transform Transition Translate TreeView TreeViewStyle Tumbler TumblerColumn TumblerStyle Turbulence 
    UniformAnimator url User 
    ValueAxis ValueAxis3D ValueAxis3DFormatter var variant VBarModelMapper VBoxPlotModelMapper VCandlestickModelMapper vector2d vector3d Vector3dAnimation vector4d VertexBlendAnimation VerticalHeaderView Video VideoOutput View3D Viewport ViewTransition Vignette VirtualKeyboardSettings VPieModelMapper VXYModelMapper 
    Wander WasdController WavefrontMesh WaylandClient WaylandCompositor WaylandHardwareLayer WaylandOutput WaylandQuickItem WaylandSeat WaylandSurface WaylandView Waypoint WebChannel WebEngine WebEngineAction WebEngineCertificateError WebEngineClientCertificateOption WebEngineClientCertificateSelection WebEngineDownloadItem WebEngineHistory WebEngineHistoryListModel WebEngineLoadRequest WebEngineNavigationRequest WebEngineNewViewRequest WebEngineNotification WebEngineProfile WebEngineScript WebEngineSettings WebEngineView WebSocket WebSocketServer WebView WebViewLoadRequest WeekNumberColumn WheelEvent WheelHandler Window WlScaler WlShell WlShellSurface WorkerScript 
    XAnimator XdgDecorationManagerV1 XdgOutputManagerV1 XdgPopup XdgPopupV5 XdgPopupV6 XdgShell XdgShellV5 XdgShellV6 XdgSurface XdgSurfaceV5 XdgSurfaceV6 XdgToplevel XdgToplevelV6 XmlListModel XmlRole XYPoint XYSeries 
    YAnimator 
    ZoomBlur'

    # ---------------------------------------------------------------------------------------------- #
    join() { sep=$2; eval set -- $1; IFS="$sep"; echo "$*"; }
    # ---------------------------------------------------------------------------------------------- #
    add_highlighter() { printf "add-highlighter shared/qml/code/ regex %s %s\n" "$1" "$2"; }
    # ---------------------------------------------------------------------------------------------- #
    add_word_highlighter() {

      while [ $# -gt 0 ]; do
          words=$1 face=$2; shift 2
          regex="\\b($(join "${words}" '|'))\\b"
          add_highlighter "$regex" "1:$face"
      done

    }

    # highlight: open<space> not open()
    add_module_highlighter() {

      while [ $# -gt 0 ]; do
          words=$1 face=$2; shift 2
          regex="\\b($(join "${words}" '|'))\\b(?=\\s)"
          add_highlighter "$regex" "1:$face"
      done

    }
    # ---------------------------------------------------------------------------------------------- #
    printf %s\\n "declare-option str-list qml_static_words $(join "${values} ${types} ${keywords} ${attributes} ${qtypes}" ' ')"
    # ---------------------------------------------------------------------------------------------- #
    add_word_highlighter "$values" "value" "$types" "type" "$keywords" "keyword" "$attributes" "attribute"
    # ---------------------------------------------------------------------------------------------- #
    add_module_highlighter "$qtypes" "+i@type"
    # ---------------------------------------------------------------------------------------------- #
}
add-highlighter shared/qml/code/ regex (\w+)(?:.(\w+))*: 1:variable 2:variable

§
