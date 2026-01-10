(
var margin=5, gap=5;
var colorButton=Color.new255(49, 49, 49);
var colorPane=Color.new255(31, 31, 31);
var colorBg=Color.new255(24, 24, 24);
var transparent=Color.grey(alpha:0.0);
var fontSmall=Font("Menlo", 10);
var fontLabel=Font("Menlo", 12);
var fontLabelLarge=Font("Menlo", 16);

// Module-wide variables (GUI elements)
var popupRoot;
var projectControlsView; // Main matrix view

// Open a directory and load project configuration files.
// The results are written to:
//     ~projectData - project configuration dictionary
//     ~rootDir - current project root directory
var openDirectory = {
    var tempData;

    FileDialog({ |path|
        var tempEvent;

        if (File.exists(path) and: { File.type(path) == \directory }) {
            tempData = ~loadProject.(path);
            if (tempData.isEmpty) {
                // No config files found - show error
                ("Error: No config files found in directory: " ++ path).error;
            } {
                // Success - update current directory and audio files
                ~rootDir = path;
                ~projectData = tempData;

                // Re-draw project controls
                projectControlsView.refresh;

                // Log success
                postf("Successfully loaded project configuration from: %\n", ~rootDir);
            };
        } {
            ("Error: Selected path is not a valid directory: " ++ path).postln;
        };
    },
    fileMode: 2, // Directory mode
    acceptMode: 0, // Open mode
    stripResult: true,

    // Warning: fix this!
    //path: PathName(thisProcess.nowExecutingPath).pathOnly
    );
};


// Toggle fullscreen mode for a given window
var toggleFullscreen = { |window|
    if (window.bounds == Window.screenBounds) {
        window.endFullScreen
    } {
        window.fullScreen
    }
};


// Header panel at the top of the window
var sectionHeader = { |parent, label|
    var panel = View(parent, (parent.bounds.width-(margin*2))@20)
        .background_(transparent);
    panel.decorator = FlowLayout(panel.bounds, margin@margin, gap@gap);

    StaticText(panel, Rect(0, 0, 400, 18))
        .string_(label)
        .font_(fontSmall)
        .align_(\topLeft)
        .stringColor_(Color.new255(152, 152, 152));

    panel;
};


// Wavetable GUI Visualizer
var section_Wavetable = {
    arg wtArr,
        makeBuffersFunc,
        parent,
        label,
        signalType,
        width=800,
        height=200;

    var scrollView, plotView;
    var plotHeight = height - 65 - (margin*4);

    // Function to update all plots
    var updateWavetablePlots = { |plotView|
        var freshArray = if(signalType == \wavetable) { ~wt_sig } { ~tf_sig };
        "> Updating wavetable plots...".postln;
        if (freshArray.notNil) {
            plotView.value = freshArray;
            plotView.refresh;
        } {
            "No wavetable signals found. Fill signals first.".warn;
        }
    };

    var panel = View(parent, (width-(margin*2))@(height-(margin*2)))
        .background_(colorPane);
    panel.decorator = FlowLayout(panel.bounds, margin@margin, gap@gap);

    sectionHeader.(panel, label);

    // Create the plot view
    plotView = Plotter(
        name: "WT",
        bounds: Rect(0, 0, width-(margin*4), plotHeight),
        parent: panel
    );
    plotView.value = wtArr;
    plotView.editMode = true;
    plotView.setProperties(
        \fontColor, Color(0.5, 1, 0);,
        \plotColor, Color.red(0.7),
        \backgroundColor, transparent,
        \gridColorX, Color.yellow(0.5),
        \gridColorY, Color.yellow(0.5),
        \gridLineSmoothing, true
    );
    plotView.refresh;

    // Add control buttons
    panel.decorator.nextLine;

    Button(panel, 120@30)
        .states_([["Refresh Plots", Color.white, colorButton]])
        .action_({ updateWavetablePlots.(plotView) });

    Button(panel, 120@30)
        .states_([["Generate New", Color.white, colorButton]])
        .action_({ 
            makeBuffersFunc.value;
            updateWavetablePlots.(plotView)
        });
};


// Helper function to calculate layout dimensions
var calculateLayoutDimensions = { |view, marginTop=0, marginBottom=0|
    var dimensions = ();
    var totalPatternCount = 0;

    // TODO: refactor - this function should be universal and
    //       not depend on ~projectData.pattern
    ~projectData.pattern.keysValuesDo { |patt, pattDef|
        totalPatternCount = totalPatternCount + pattDef[\patterns].size;
    };

    dimensions[\totalHeight] = view.bounds.height - (margin*2) - marginTop - marginBottom;
    dimensions[\totalPatternCount] = totalPatternCount;
    dimensions[\localGap] = 15;
    dimensions[\textMargin] = 10;
    dimensions[\cornerRadius] = 10;
    dimensions[\boxWidth] = view.bounds.width/6;
    
    dimensions;
};

// Function to draw a single pattern group box with sub-patterns
var drawPatternGroup = { |patt, pattDef, groupIndex, dimensions, currentYPos, patternBoxes|
    var groupHeight = (dimensions[\totalHeight] / ~projectData.pattern.keys.size) - dimensions[\localGap];
    var subBoxHeight = (groupHeight - (dimensions[\textMargin] * 8)) / pattDef[\patterns].size - dimensions[\localGap];
    var groupBoxRect = Rect(0, currentYPos, dimensions[\boxWidth], groupHeight);
    var subBoxYPos;
    
    // Draw main pattern group box
    Pen.fillColor = Color.new255(19, 26, 42);
    Pen.strokeColor = Color.gray(0.2);
    Pen.addRoundedRect(groupBoxRect, dimensions[\cornerRadius], dimensions[\cornerRadius]);
    Pen.fillStroke;

    // Store connection point for this group
    patternBoxes[patt] = Point(
        groupBoxRect.right,
        groupBoxRect.top + (groupBoxRect.height/2)
    );

    // Draw pattern group name
    Pen.fillColor = Color.white;
    Pen.font = fontLabelLarge;
    Pen.stringAtPoint(patt.asString, Point(dimensions[\textMargin], currentYPos + dimensions[\textMargin]));

    // Draw sub-pattern boxes
    subBoxYPos = currentYPos + (dimensions[\textMargin] * 4) + fontLabelLarge.size + dimensions[\localGap];
    
    pattDef[\patterns].do { |patternName, patternIndex|
        drawSubPatternBox.(patternName, subBoxYPos, subBoxHeight, dimensions);
        subBoxYPos = subBoxYPos + subBoxHeight + (dimensions[\localGap]/2);
    };
    
    // Return new Y position for next group
    currentYPos + groupHeight + dimensions[\localGap];
};

// Function to draw a single sub-pattern box
var drawSubPatternBox = { |patternName, yPos, height, dimensions|
    var subBoxRect = Rect(
        dimensions[\textMargin] * 2, 
        yPos,
        dimensions[\boxWidth] * 0.75, 
        height
    );

    // Draw sub-box
    Pen.fillColor = Color.new255(35, 45, 70);
    Pen.strokeColor = Color.gray(0.4);
    Pen.addRoundedRect(subBoxRect, dimensions[\cornerRadius]/2, dimensions[\cornerRadius]/2);
    Pen.fillStroke;

    // Draw pattern name
    Pen.fillColor = Color.gray(0.8);
    Pen.font = fontLabel;
    Pen.stringAtPoint(
        patternName.asString, 
        Point(
            subBoxRect.left + (dimensions[\textMargin]/2), 
            subBoxRect.top + (dimensions[\textMargin]/2)
        )
    );
};

// Function to draw all pattern groups
var drawPatternGroups = { |view, dimensions, patternBoxes|
    var currentYPos = 0;
    
    ~projectData.pattern.keysValuesDo { |patt, pattDef, groupIndex|
        currentYPos = drawPatternGroup.(patt, pattDef, groupIndex, dimensions, currentYPos, patternBoxes);
    };
};

// Function to draw a single synth sub-box within a tone unit
var drawSynthSubBox = { |synthDef, synthIndex, subBoxRect, dimensions|
    var typeLabel = synthDef[\type] ? "";
    var synthNameClean = synthDef[\synthName].asString.split($_)[1..].join($_);
    var synthLabel = format("% [%]", synthNameClean, synthDef[\synth].nodeID);
    var synthLabelSize = synthLabel.bounds(Pen.font);

    // Draw sub-box
    Pen.fillColor = Color.new255(50, 60, 85);
    Pen.strokeColor = Color.gray(0.5);
    Pen.addRoundedRect(subBoxRect, dimensions[\cornerRadius]/3, dimensions[\cornerRadius]/3);
    Pen.fillStroke;

    // Draw type label (top-left)
    Pen.fillColor = Color.gray(0.9);
    Pen.font = fontLabel;
    Pen.stringAtPoint(
        typeLabel.asString, 
        Point(
            subBoxRect.left + (dimensions[\textMargin]/2), 
            subBoxRect.top + (dimensions[\textMargin]/3)
        )
    );

    // Draw synth name + nodeID (top-right, smaller font)
    Pen.fillColor = Color.gray(0.7);
    Pen.font = Font("Menlo", 10);
    Pen.stringAtPoint(
        synthLabel.asString, 
        Point(
            subBoxRect.left + (dimensions[\textMargin]/2),
            subBoxRect.top + (dimensions[\textMargin]*3)
        )
    );
};

// Function to draw tone unit boxes with synth sub-boxes
var drawToneUnits = { |view, dimensions, toneBoxes|
    var boxHeight = 100;
    var boxWidth = view.bounds.width/6;
    var xPos = view.bounds.width/4 + margin;
    var yPos = (dimensions[\totalHeight] - (~projectData.tone.keys.size * boxHeight) - ((~projectData.tone.keys.size - 1) * dimensions[\localGap])) / 2;

    ~projectData.tone.keysValuesDo { |key, toneDef|
        var boxRect = Rect(xPos, yPos, boxWidth, boxHeight);
        var textRect = boxRect.insetBy(dimensions[\textMargin], dimensions[\textMargin]/2);
        var synthsArray = toneDef[\synths] ? [];
        var subBoxHeight = (boxHeight - (dimensions[\textMargin] * 3)) / 1.5; // Reserve space for main label
        var subBoxRect, subBoxWidth, subBoxXPos, subBoxYPos;
        var nodeIDText = format("[%]", toneDef[\nodeID].asString);
        var nodeIDSize = nodeIDText.bounds(Pen.font);

        // Store connection point
        toneBoxes[key] = Point(
            boxRect.left,
            boxRect.top + (boxRect.height/2)
        );

        // Draw main tone unit box
        Pen.width = 1;
        Pen.fillColor = Color.gray(0.2);
        Pen.addRoundedRect(boxRect, dimensions[\cornerRadius], dimensions[\cornerRadius]);
        Pen.fill;

        // Draw main tone unit label at the top left
        Pen.fillColor = Color.white;
        Pen.font = fontLabelLarge;
        Pen.stringAtPoint(key.asString, Point(boxRect.left + dimensions[\textMargin], boxRect.top + dimensions[\textMargin]));
        
        // Draw nodeID label at the top right
        Pen.fillColor = Color.grey;
        Pen.font = fontLabel;
        Pen.stringAtPoint(
            nodeIDText,
            Point(
                boxRect.right - nodeIDSize.width - dimensions[\textMargin], 
                boxRect.top + dimensions[\textMargin]
            )
        );

        // Draw synth sub-boxes horizontally
        if (synthsArray.size > 0) {
            subBoxWidth = (boxWidth - (dimensions[\textMargin] * (synthsArray.size + 1))) / synthsArray.size;
            subBoxYPos = boxRect.top + (dimensions[\textMargin] * 2) + fontLabelLarge.size;
            
            synthsArray.do { |synthDef, synthIndex|
                subBoxXPos = boxRect.left + dimensions[\textMargin] + (synthIndex * (subBoxWidth + dimensions[\textMargin]));
                subBoxRect = Rect(subBoxXPos, subBoxYPos, subBoxWidth, subBoxHeight);
                drawSynthSubBox.(synthDef, synthIndex, subBoxRect, dimensions);
            };
        };

        yPos = yPos + (boxHeight + dimensions[\localGap]);
    };
};

// Function to draw connections between pattern groups and tone units
var drawConnections = { |patternBoxes, toneBoxes|
    Pen.width = 2;
    Pen.strokeColor = Color.green(0.5);

    ~projectData.pattern.keysValuesDo { |key, patternData|
        var startPoint = patternBoxes[key];
        var endPoint = toneBoxes[patternData.tone];

        if (startPoint.notNil and: { endPoint.notNil }) {
            var ctrlPoint1 = Point(
                startPoint.x + ((endPoint.x - startPoint.x) * 0.5),
                startPoint.y
            );
            var ctrlPoint2 = Point(
                startPoint.x + ((endPoint.x - startPoint.x) * 0.5),
                endPoint.y
            );

            Pen.moveTo(startPoint);
            Pen.curveTo(endPoint, ctrlPoint1, ctrlPoint2);
            Pen.stroke;
        };
    };
};

// Main drawing function - now much cleaner!
var drawPattGroupControls = { |view|
    var dimensions = calculateLayoutDimensions.(view, marginBottom:200);
    var patternBoxes = Dictionary.new;
    var toneBoxes = Dictionary.new;

    // Draw all components
    drawPatternGroups.(view, dimensions, patternBoxes);
    drawToneUnits.(view, dimensions, toneBoxes);
    drawConnections.(patternBoxes, toneBoxes);
};


var makeProjectControls = { |parent|
    var totalHeight=parent.bounds.height - (margin*2);
    var userView = UserView(parent, Rect(0, 0, parent.bounds.width, totalHeight))
        .background_(Color.clear)
        .drawFunc_({ |view|
            var reportNoProjectData = {
                Pen.fillColor = Color.red(0.8);
                Pen.font = fontLabel;
                Pen.stringAtPoint("No project data loaded.", Point(margin*4, margin*4));
            };

            if (~projectData.isNil) {
                reportNoProjectData.();
            } {
                if (~projectData.isEmpty) {
                    reportNoProjectData.();
                } {
                    // Draw pattern group controls
                    drawPattGroupControls.(view);
                };
            };
        });

    userView;
};


// Panel and controls for operations with project files (load/save, etc)
var section_Projects = { |parent, width, height|
    var buttonLoad, buttonSave;
    var ctrlPaneProjects = View(parent, width@height).background_(colorPane);
    ctrlPaneProjects.decorator = FlowLayout(ctrlPaneProjects.bounds, margin@margin, gap@gap);

    sectionHeader.(ctrlPaneProjects, "Projects");

    // Create project operation buttons
    buttonLoad = Button(ctrlPaneProjects, 50@30)
        .string_("Load")
        .action_({ |bt| openDirectory.() });
    buttonSave = Button(ctrlPaneProjects, 50@30)
        .string_("Save")
        .action_({ |bt| ~saveFile.() });
};

// Panel and controls for harmony (root note, scale, etc)
var section_Harmony = { |parent, width, height|
    var popupRoot, rootWatcher;
    var ctrlPaneNotes = View(parent, width@height).background_(colorPane);

    ctrlPaneNotes.decorator = FlowLayout(ctrlPaneNotes.bounds, margin@margin, gap@gap);

    sectionHeader.(ctrlPaneNotes, "Harmony");

    popupRoot = PopUpMenu(ctrlPaneNotes, 200@30)
        .items_(~fullNoteList)
        .value_(~defaultIndex)
        .action_({ |menu| ~setRoot.(menu.value) });

    // Root watcher setup
    rootWatcher = Routine({
        loop {
            var index = ~midiValues.indexOf(~rootMIDI);
            {
                if (index.notNil and: { popupRoot.value != index }) {
                    popupRoot.value_(index);
                };

                // Keep it running only while the window is open
                if (~win.isClosed) { rootWatcher.stop };
            }.defer;
            0.5.yield;
        }
    }).play;
};


// Warning: obsolete, remove after completing section_SignalFlowGraph
//
// Panel and controls for transport (play/stop, tempo, etc)
var section_Transport = { |parent, width, height|
    var btPlay;

    var ctrlPaneTransp = View(parent, width@height).background_(colorPane);

    ctrlPaneTransp.decorator = FlowLayout(ctrlPaneTransp.bounds, margin@margin, gap@gap);

    sectionHeader.(ctrlPaneTransp, "Transport");

    // Place controls in their respective panels
    btPlay = Button(ctrlPaneTransp, 50@50)
        .states_([
            ["MIX", Color.white, Color.gray],
            ["MIX", Color.white, Color.red(0.4)]
        ])
        .action_({ |bt|
            var fullMixName = \mix_full;
            if (~evnts[fullMixName].isNil) {
                postf("WARNING: No event defined for '%'\n", fullMixName);
            } {
                ~tempo.schedAbs(~tempo.nextTimeOnGrid(), {
                    if (~evnts[fullMixName].value.isPlaying) {
                        ~evnts[fullMixName].value.stop;
                    } {
                        ~evnts[fullMixName].value.play;
                    };
                    nil;
                });
            };
        });
};


var section_SignalFlowGraph = {
    arg parent, width=400, height=50;

    // Not all keys should have buttons, e.g., the full mix button
    var guiPatternKeys = [
        \beat_x1, \beat_x2, \pad, \pad_s, \bass, \pulse, \melody
    ].asArray;

    var ctrlPaneProject = View(parent, (width-(margin*2))@(height-(margin*2)))
        .background_(colorPane);
    ctrlPaneProject.decorator = FlowLayout(ctrlPaneProject.bounds, margin@margin, gap@gap);

    StaticText(ctrlPaneProject, Rect(0, 0, width, 20))
        .string_("Patterns")
        .font_(fontLabel)
        .stringColor_(Color.white);

    // Create pattern control panels
    ctrlPaneProject.decorator.nextLine;

    projectControlsView = makeProjectControls.(ctrlPaneProject);
};


// Main GUI creation function
~makeGUI = {
    var winWidth = 2000;
    var winHeight = Window.screenBounds.height-55;
    var palette = QPalette.dark;
    var btPlay;
    var panelTop, panelMain, panelBottom;
    var ctrlPaneTransp, ctrlPaneNotes, plotPanel1, plotPanel2;
    var panelHeight = 150;  // height for control panels
    var plotPanelHeight = winHeight-panelHeight-(margin*4);  // remaining height for plot panels

    ~win = Window.new(
        "Cyklop",
        Rect(
            Window.screenBounds.width-(winWidth*2),
            1500,
            winWidth,
            Window.screenBounds.height-55
        ),
        resizable: false
    );
    ~win.view.decorator = FlowLayout(~win.view.bounds);
    ~win.view.decorator.gap=gap@gap;    
    palette.setColor(colorBg, \window);
    ~win.view.palette = palette;

    // Create a top-order panels
    panelTop = View(~win, (winWidth-margin)@(winHeight/8))
        .background_(colorPane);
    panelTop.decorator = FlowLayout(panelTop.bounds, margin@margin, gap@gap);

    // Main panel in the middle for plots, controls and routing
    panelMain = View(~win, (winWidth-(margin*2))@(winHeight-panelTop.bounds.height-30-(margin*2)))
        .background_(colorPane);
    panelMain.decorator = FlowLayout(panelMain.bounds, margin@margin, gap@gap);

    // Panel for statistics or other info at the bottom
    panelBottom = View(~win, (winWidth-margin)@30)
        .background_(colorPane);
    panelBottom.decorator = FlowLayout(panelBottom.bounds, margin@margin, gap@gap);

    // Make panel with file controls (load/save, etc)
    section_Projects.(
        parent: panelTop,
        width: (winWidth/4)-(margin*2),
        height: panelTop.bounds.height-(margin*2)
    );

    // Make panel with controls related to harmony (root note, scale, etc)
    section_Harmony.(
        parent: panelTop,
        width: (winWidth/4)-(margin*2),
        height: panelTop.bounds.height-(margin*2)
    );

    section_Transport.(
        parent: panelTop,
        width: (winWidth/2)-(margin*2),
        height: panelTop.bounds.height-(margin*2)
    );

    // Warning: those will become GUI for synths used in patterns (\instrument)
    //          and will be opening automatically when a pattern is selected.
    // Adjacent panels for the wavetable GUI (plots)
    // section_Wavetable.(
    //     ~wt_sig,
    //     ~makeWavetableBufs,
    //     panelMain,
    //     "Wavetables (Osc & VOsc)",
    //     signalType: \wavetable,
    //     width: panelMain.bounds.width/5,
    //     height: panelMain.bounds.height
    // );

    // section_Wavetable.(
    //     ~tf_sig,
    //     ~makeShaperBufs,
    //     panelMain,
    //     "Transfer Functions (Shaper)",
    //     signalType: \transfer,
    //     width: panelMain.bounds.width/5,
    //     height: panelMain.bounds.height
    // );

    section_SignalFlowGraph.(
        parent: panelMain,
        width: panelMain.bounds.width * 0.75,
        height: panelMain.bounds.height
    );

    // Set up key handlers
    ~win.view.keyDownAction_({ |view, char, modifiers, unicode, keycode|
        case
        // Cmd+O: open directory
        { (modifiers.bitAnd(1048576) != 0) && (char == $o) } { openDirectory.() }
        // Cmd+O: open directory
        { (modifiers.bitAnd(1048576) != 0) && (char == $s) } { ~saveFile.() }
        // Ctrl+F: toggle fullscreen
        { (modifiers.bitAnd(262144) != 0) && (char == $f) } { toggleFullscreen.(~win) }
        // ESC: exit fullscreen
        { (modifiers == 0) && (keycode == 53) } {  ~win.endFullScreen }
        // ...all the rest
        { [view, char, modifiers, unicode, keycode].postln }
    });


    ~win.front;
};
)