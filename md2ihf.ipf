#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3				// Use modern global access method and strict wave access
#pragma DefaultTab={3,20,4}		// Set default tab width in Igor Pro 9 and later

// Element type constants
Constant NoElement = 0
Constant LinkElement = 1
Constant HTMLLinkElement = 2
Constant HTMLImageElement = 3
Constant ImageElement = 4
Constant CodeElement = 5
Constant FencedCodeElement = 6
Constant BoldElement = 7
Constant ItalicElement = 8
Constant SuperscriptElement = 9
Constant SubscriptElement = 10
Constant LineBreakElement = 11
Constant TableElement = 12
Constant QuoteElement = 13
Constant HTMLSpanElement = 14

StrConstant baseFont = "Helvetica"
StrConstant baseCodeFont = "Consolas"
Constant baseFontSize = 10

// If this ever changes, you'll need to update the setTableTabs() function to
// accommodate the additional table columns
Constant maxNumTableCols = 8
Constant maxNumNestedRows = 100 // ModifyCamera actually requires about this many...

Constant notebookDPI = 72

structure TextFormat
	Variable format // Bitfield for bold, italic, etc.
	Variable fSize // Size of the font
	Variable vOffset // For super/sub script
	struct RGBColor rgb // Color
endstructure

structure LineContext
	Variable isList
	Variable isListParagraph
	double listIndent[10]
	double listLeft[10]
	Variable listDepth
	Variable leftMargin
	Variable listLength
	Variable isQuote
	Variable isTable
	Variable tableColumn
	Variable isCodeBlock
	Variable isFirstElementInLine
	struct TextFormat textFormat
endstructure

Structure TableStats
	Variable nCols // Number of columns in the table (does not consider nested columns)
	Variable colWidth[maxNumTableCols] // Widths of the main columns in the table, not counting nested columns.
	Variable nestedColWidth[maxNumNestedRows] // For subcolumns that might occur in the last column of the table. 
								// indicates that we could have up to maxNumNestedRows rows that have nesting in the table
	String nestedColRows // A semi-colon separated list of the table rows that contain nested columns
	Variable cellIsNested // This gets set if the current row, col requires nesting
	Variable extraBuffer // Miscellaneous extra buffer that we might want in certain situations. Like rendering a code
						 // block inside a table cell
	Variable tableCellIsPreformat // 1 if the table cell being rendered is a preformat block (code block)

EndStructure

// Sets up some different rulers that we'll need to use for
// different markdown elements/headers
//
// notebookName		: Name of the notebook
Static Function setupRulers(String notebookName)
	// Main topic, H1 maps to this
	Notebook $notebookName newRuler = Topic
	Notebook $notebookName ruler = Topic, rulerDefaults = {baseFont, baseFontSize + 2, 1|4, (0,0,0,0)}, spacing = {6, 6, 1}, tabs = {points(3/16)}, margins = {0, 0, points(6.5)}
	
	// Subtopic, H2 maps to this
	Notebook $notebookName newRuler = Subtopic
	Notebook $notebookName ruler = Subtopic, rulerDefaults = {baseFont, baseFontSize, 1|4, (0,0,0,0)}, spacing = {6, 6, 1}, margins = {points(3/16), points(3/16), points(6.5)}

	Notebook $notebookName newRuler = H3
	Notebook $notebookName ruler = H3, rulerDefaults = {baseFont, baseFontSize, 1, (0,0,0,0)}, spacing = {3, 3, 1}, margins = {points(5/16), points(5/16), points(6.5)}
	
	Notebook $notebookName newRuler = H4
	Notebook $notebookName ruler = H4, rulerDefaults = {baseFont, baseFontSize, 1, (0,0,0,0)}, spacing = {3, 3, 1}, margins = {points(5/16), points(5/16), points(6.5)}
	
	Notebook $notebookName newRuler = Paragraph
	Notebook $notebookName ruler = Paragraph, rulerDefaults = {baseFont, baseFontSize, 0, (0,0,0,0)}, spacing = {3, 3, 1}, margins = {points(3/16), points(3/16), points(6.5)}
	
	Notebook $notebookName newRuler = IndentedParagraph
	Notebook $notebookName ruler = IndentedParagraph, rulerDefaults = {baseFont, baseFontSize, 0, (0,0,0,0)}, spacing = {3, 3, 1}, margins = {points(5/16), points(5/16), points(6.5)}
	
	Notebook $notebookName newRuler = List
	Notebook $notebookName ruler = List, rulerDefaults = {baseFont, baseFontSize, 0, (0,0,0,0)}, spacing = {3, 3, 1}, margins = {points(5/16), points(7/16), points(6.5)}

	Notebook $notebookName newRuler = ListParagraph
	Notebook $notebookName ruler = ListParagraph, rulerDefaults = {baseFont, baseFontSize, 0, (0,0,0,0)}, spacing = {3, 3, 1}, margins = {points(7/16), points(7/16), points(6.5)}

	// Fenced code blocks and back-ticked text map to this
	Notebook $notebookName newRuler = Code_Igor
	Notebook $notebookName ruler = Code_Igor, rulerDefaults = {baseCodeFont, baseFontSize, 0, (0,0,0,0)}, spacing = {0, 0, 1}, margins = {points(5/16), points(5/16), points(12)}
	
	Notebook $notebookName newRuler = Code_Other
	Notebook $notebookName ruler = Code_Other, rulerDefaults = {baseCodeFont, baseFontSize, 0, (0x5000,0x5000,0x5000,0)}, spacing = {0, 0, 1}, margins = {points(5/16), points(5/16), points(12)}
	
	Notebook $notebookName newRuler = Code_Python
	Notebook $notebookName ruler = Code_Python, rulerDefaults = {baseCodeFont, baseFontSize, 0, (0,0,0,0)}, spacing = {0, 0, 1}, margins = {points(5/16), points(5/16), points(12)}
	
	Notebook $notebookName newRuler = Padding
	Notebook $notebookName ruler = Padding, rulerDefaults = {baseCodeFont, baseFontSize/2, 0, (0,0,0,0)}, spacing = {0, 0, 1}, margins = {0, 0 , points(6.5)}

	Notebook $notebookName newRuler = Table
	Notebook $notebookName ruler = Table, rulerDefaults = {baseFont, baseFontSize, 0, (0,0,0,0)}, spacing = {3, 3, 1}, margins = {points(5/16), points(5/16), points(6.5)}
	
	Notebook $notebookName newRuler = QuoteHeader
	Notebook $notebookName ruler = QuoteHeader, rulerDefaults = {baseFont, baseFontSize, 0, (0x5000,0x5000,0x5000,0)}, spacing = {3, 0, 1}, margins = {points(5/16), points(5/16), points(6)}
	
	Notebook $notebookName newRuler = Quote
	Notebook $notebookName ruler = Quote, rulerDefaults = {baseFont, baseFontSize, 0, (0x5000,0x5000,0x5000,0)}, spacing = {3, 3, 1}, margins = {points(6/16), points(6/16), points(6)}
	
	
End

static function points(Variable inches)
	return inches * notebookDPI
end 

// Returns the number of tabs at the start of the line
static Function nLeadingTabs(String line)
	Variable index = 0
	Variable nTabs = -1
	do
		nTabs++
	while (!CmpStr(line[index++], "\t"))
	return nTabs
End

// Returns truth that the first character in the text string is the bullet character
static function firstCharIsBullet(String text)
	return strsearch(text, "•", 0, 0) == 0
end

// Returns truth that the first character in the text string is numeric
static function firstCharIsNumber(String text)
	
	return numtype(str2num(text[0])) != 2
end

// Sets the margin positions given the current context of the line.
// If the current list depth has already been calculated, then nothing will will happen here.
//
// context	:	Current context of the line
// listType	:	Type of list (1 is unordered/bulleted, 2 is ordered/numbered list)
static function setListMargin(struct LineContext& context, Variable listType)
	Variable i, extraSpace
	
	if (context.listLength > 9)
		extraSpace = 1/16
	elseif (context.listLength > 99)
		extraSpace = 2/16
	endif
	
	if (context.listDepth == 0 && context.listIndent[0] == 0)
		// These starting positions are based on the default rulers defined in setupRulers()
		// The numbered list gets a slightly deeper indent to leave space for more than one digit
		context.listIndent[0] = context.leftMargin
		
		if (listType == 1)
			// Bulleted
			context.listLeft[0] = context.leftMargin + 2/16 
		elseif (listType == 2)
			// Numbered
			context.listLeft[0] = context.leftMargin + 3/16 + extraSpace
		endif
		return 0
	endif
	
	if (context.listDepth > 0)
		// Haven't defined this depth yet
		if (listType == 1)
			// Bulleted
			context.listIndent[context.listDepth] = context.listLeft[context.listDepth - 1]
			context.listLeft[context.listDepth] = context.listIndent[context.listDepth] + 2/16
		elseif (listType == 2)
			// Numbered
			context.listIndent[context.listDepth] = context.listLeft[context.listDepth - 1]
			context.listLeft[context.listDepth] = context.listIndent[context.listDepth] + 3/16 + extraSpace
		endif
	endif
end

// Re-initializes the context structure data
static function clearContext(struct LineContext& context)
	context.isList = 0
	context.isTable = 0
	context.isQuote = 0
	context.tableColumn = 0
	context.listDepth = 0
	context.listLength = 0
	context.isCodeBlock = 0
	context.isFirstElementInLine = 1
	context.isListParagraph = 0
	
	Variable i
	for (i = 0; i < 10; i++)
		context.listIndent[i] = 0
		context.listLeft[i] = 0
	endfor
	
	context.textFormat.format = 0
	context.textFormat.fSize = baseFontSize
	context.textFormat.vOffset = 0
	context.textFormat.rgb.red = 0
	context.textFormat.rgb.green = 0
	context.textFormat.rgb.blue = 0
end

// Given a string, finds the next tag in the string and sets the startPos and endPos locations.
// Note, startPos and endPos are passed by reference, and are modified by the functions.
//
// This should allow calling functions to extract the full tag text
// For example:
// "<IgorLink>[Python Integration in Igor Pro 10]()</IgorLink>"
//
// text		: Text to search for the next element in
// startPos	: Position to start the search at, and filled with the start position of the found element. 
//			  Note, this is a reference, and is modified by the function.
// endPos	: End position of the found element. 
//			  Note, this is a reference, and is modified by the function
// isTable	: Optional. Set to true if searching for elements within a table cell.
Static Function findNextElementLocation(String text, Variable& startPos, Variable& endPos, [Variable isTable])
	Variable whichElement = NoElement

	// whichTag : recovers tags with open/close pairs, e.g. <IgorBold>Bold text</IgorBold>
	// nonClosingTag : recovers tags that don't immediately close, e.g. <img src="path/to/image.png"/>
	// simpleTag : recovers simple tags that stand on their own, without an open/closing pair, e.g. <br>
	String whichTag, nonClosingTag, simpleTag
	
	endPos = startPos
	
	do
		startPos = endPos
		
		String partialText = text[startPos,strlen(text)-1] 
		SplitString/E="(?:<(\w+)>?.*?</\1>)|(?:<(\w+).*?/>)|(?:<(\w+)>)" partialText, whichTag, nonClosingTag, simpleTag
			
		if (strlen(whichTag) == 0)
			if (strlen(nonClosingTag) == 0)
				if (strlen(simpleTag) == 0)
					return NoElement
				else
					whichTag = simpleTag
				endif
			else
				whichTag = nonClosingTag
			endif
					
		endif

		Variable foundPos = strsearch(partialText, S_Value, 0, 0)
		startPos += foundPos
		endPos = startPos + strlen(S_Value) - 1
		
		// Need to unpack the language
		if (stringmatch(whichTag, "IgorFencedCode_*"))
			whichTag = "IgorFencedCode"
			// The end position will always be the end of the string here,
			// Since it was parsed in getInlineFencedCode()
			endPos = endPos + strlen(partialText) - strlen("</IgorFencedCode>")
		elseif (!cmpstr(whichTag, "IgorTable"))
			endPos = endPos + strlen(partialText) - strlen("</IgorTable>") + 1
		elseif (!cmpstr(whichTag, "IgorQuote"))
			endPos = endPos + strlen(partialText) - strlen("</IgorQuote>") + 1
		endif
		
		strswitch (whichTag)
			case "IgorLink":
				whichElement = LinkElement
				break
			case "IgorHTML":
				whichElement = HTMLLinkElement
				break
			case "IgorImage":
				whichElement = ImageElement
				break
			case "IgorBold":
				whichElement = BoldElement
				break
			case "IgorItalic":
				whichElement = ItalicElement
				break
			case "IgorCode":
				whichElement = CodeElement
				break
			case "IgorFencedCode":
				whichElement = FencedCodeElement
				break
			case "IgorTable":
				whichElement = TableElement
				break
			case "IgorQuote":
				whichElement = QuoteElement
				break
			case "span":
				whichElement = HTMLSpanElement
				break
			case "img":
				whichElement = HTMLImageElement
				break
			case "sub":
				whichElement = SubscriptElement
				break
			case "sup":
				whichElement = SuperscriptElement
				break
			case "br":
				// Extend the end point of this tag to include any whitespace beyond it
				// since that will be at the start of the next line and shouldn't be rendered.
				// We ignore tab whitespace in Tables, though, since the tabs are required to
				// indicate which column the text paragraph is in
				Variable shouldIgnoreTabs = isTable
				do
					String c = text[endPos+1]
					if (!cmpstr(c, " ") || (!shouldIgnoreTabs && !cmpstr(c, "\t")))
						endPos += 1
					else
						break
					endif 
				while (endPos < strlen(partialText))
				whichElement = LineBreakElement
				break
			default:
				// This means we DID find a 'tag' element, but it wasn't something that we support. This
				// could also mean that the markdown file contained an escaped angle bracket element, like:
				// \<precision\>, which is picked up by the regular expression. In either case, we continue the
				// search after this position.  
				whichElement = NoElement
				break
		endswitch
	while (whichElement == NoElement)

	return whichElement
End

// Draws any inline element into the notebook
//
// notebookName		: Name of the notebook
// elementType		: Type of the element to be inserted (see constants at top of file)
// elementText		: Text of the element
// doHighlight		: Set to 1 to allow syntax highlighting of CodeElements
Static Function drawElementInNotebook(String notebookName, Variable elementType, String elementText, struct LineContext& context)
	switch (elementType)
		case LinkElement:
			drawLinkInNotebook(notebookName, elementText, context)
			break
		case HTMLLinkElement:
			drawHTMLLinkInNotebook(notebookName, elementText, context)
			break
		case HTMLImageElement:
		case HTMLSpanElement:
		case SubscriptElement:
		case SuperscriptElement:
		case LineBreakElement:
			drawHTMLTagInNotebook(notebookName, elementText, elementType, context)
			break
		case ImageElement:
			drawImageInNotebook(notebookName, elementText, context)
			break
		case CodeElement:
			drawInlineCodeInNotebook(notebookName, elementText, context)
			break		
		case BoldElement:
			drawBoldTextInNotebook(notebookName, elementText, context)
			break
		case ItalicElement:
			drawItalicTextInNotebook(notebookName, elementText, context)
			break
		case FencedCodeElement:
			String language, codeText
			SplitString/E="<IgorFencedCode_(.*?)>([\S\s]*)</IgorFencedCode>" elementText, language, codeText
			drawFencedCode(notebookName, codeText, language, context)
			break
		case TableElement:
			String tableText
			SplitString/E="<IgorTable>([\S\s]*)</IgorTable>" elementText, tableText
			drawTableElements(notebookName, tableText, context)
			break
		case QuoteElement:
			String quoteText
			SplitString/E="<IgorQuote>([\S\s]*)</IgorQuote>" elementText, quoteText
			if (context.isTable)
				// Inside a table, so we don't want special margin formatting for a full size quote
				// This quote will be inside a table cell
				drawTableCellQuoteElement(notebookName, quoteText, context)
			else
				drawQuoteElement(notebookName, quoteText, context)
			endif
			break
	endswitch	
End

// Draws the link defined by linkText in the named notebook
//
// notebookName		: Name of the notebook
// linkText			: Text that defines a link (either internal, or an experiment action)
//					  to insert into the named notebook. HTML web links use drawHTMLLinkInNotebook()
Static Function drawLinkInNotebook(String notebookName, String linkText, struct LineContext& context)
	String title, dest, pxpAction
	SplitString/E="<IgorLink>\[(.*)\]\((.*)\)</IgorLink>" linkText, title, dest
	
	if (strlen(dest))				
		Variable isAction = 0
		// Is this an HTML link or an Igor experiment action?
		pxpAction = StringByKey("IgorPXP", dest, ":")
		if (strlen(pxpAction))
			// Experiment open action
			isAction = 1
		else
			// Treat as HTML
			isAction = 0
			title = dest
			if (Cmpstr(dest[0], "<") != 0)
				title = "<" + title
			endif
			
			if (CmpStr(dest[strlen(dest)-1], ">") != 0)
				title += ">"
			endif

		endif
	endif
	
	GetSelection notebook, $notebookName, 1
	
	if (isAction)
		String commandStr
		
		// If there were spaces in the name of the experiment file, they got replaced with double underscores,
		// so they need to be replaced back to spaces here
		pxpAction = ReplaceString("__", pxpAction, " ")
		sprintf commandStr, "Execute/P/Q \"LOADHELPEXAMPLE :%s\"", pxpAction
		
		String actionName = UniqueName("OpenExperiment_", 16, 0, notebookName)
		NotebookAction/W=$notebookName name = $actionName, commands = commandStr, title = title, procPICTName = WMDemoLoader#IgorDemoExperimentIcon, showMode = 5
	else
		Notebook $notebookName, text = title
		Notebook $notebookName, selection={(V_startParagraph, V_startPos), endOfParagraph}, textRGB=(0,0,0xffff), fStyle = 4
		Notebook $notebookName, selection={endOfFile, endOfFile}, textRGB=(0,0,0), fStyle = 0
	endif
	
	context.isFirstElementInLine = 0
End

// Draws the HTML link defined by linkText in the named notebook
//
// notebookName		: Name of the notebook
// linkText			: Text that defines an HTML web link
Static Function drawHTMLLinkInNotebook(String notebookName, String linkText, struct LineContext& context)
	String dest
	SplitString/E="<IgorHTML>(.*)</IgorHTML>" linkText, dest
	
	GetSelection notebook, $notebookName, 1
	
	Notebook $notebookName, text = dest
	Notebook $notebookName, selection={(V_startParagraph, V_startPos), endOfParagraph}, textRGB=(0,0,0xffff), fStyle = 4
	Notebook $notebookName, selection={endOfFile, endOfFile}
	Notebook $notebookName, textRGB=(0,0,0), fStyle = 0
	
	context.isFirstElementInLine = 0
End

// Draws the input text according to the properties defined in the line context
// notebookeName	: Name of the notebook
// theText			: The text to draw
// context			: Current context data for the line
static Function drawTextInContext(String notebookName, String theText, struct LineContext& context)
	Notebook $notebookName, fStyle = context.textFormat.format, 		\
							vOffset = context.textFormat.vOffset, 	\
							fSize = context.textFormat.fSize, 		\
							textRGB = (context.textFormat.rgb.red, context.textFormat.rgb.green, context.textFormat.rgb.blue), \
							text = theText
	context.isFirstElementInLine = 0
end

// Draws the HTML tag element defined by elementText in the named notebook
//
// notebookName		: Name of the notebook
// elementText		: Text that defines an HTML tag element
Static Function drawHTMLTagInNotebook(String notebookName, String elementText, Variable type, struct LineContext& context)
	String tagText = ""
	switch (type)
		case SuperscriptElement:
			SplitString/E="<sup>(.*)</sup>" elementText, tagText
			break
		case SubscriptElement:
			SplitString/E="<sub>(.*)</sub>" elementText, tagText
			break
	endswitch

	Variable startPos = 0
	Variable endPos = 0
	
	String remainingText = tagText
	
	Variable scriptFontSize = baseFontSize * 0.75
	
	if (type == SuperscriptElement)
		context.textFormat.vOffset = -3
		context.textFormat.fSize = scriptFontSize
	elseif (type == SubscriptElement)
		context.textFormat.vOffset = 3
		context.textFormat.fSize = scriptFontSize
	endif
	
	// This loop will allow us to process nested HTML tags, like if we have bold text
	// inside a superscript, or something like that
	do
		Variable whichElement = findNextElementLocation(remainingText, startPos, endPos)

		if (whichElement != NoElement)
			// Draw up until the nested element
			GetSelection notebook, $notebookName, 1
			drawTextInContext(notebookName, remainingText[0, startPos - 1], context)
			Notebook $notebookName,fStyle = 0

			// Draw the nested element recursively
			drawElementInNotebook(notebookName, whichElement, remainingText[startPos, endPos], context)
			remainingText = remainingText[endPos + 1, inf]
		else
			switch (type)
				case SuperscriptElement:
				case SubscriptElement:
					drawTextInContext(notebookName, remainingText, context)
					break
				case HTMLSpanElement:
				case HTMLImageElement:
					drawHTMLBlockElement(notebookName, elementText, context)
					break
				case LineBreakElement:
					Notebook $notebookName text = "\n"
					break
				default:
					drawTextInContext(notebookName, remainingText, context)
					break
			endswitch
		endif
	while (whichElement != NoElement)
	
	context.textFormat.vOffset = 0
	context.textFormat.fSize = baseFontSize
End


// Draws the image defined by imageText in the named notebook
//
// This draws an image using the basic ![altText](imagepath) syntax.
// This generally shouldn't be used because it gives no control over the size of the image
// <img src=imagepath, alt=altText, width=pct%/> is the preferred syntax.
//
// notebookName		: Name of the notebook
// imageText		: Text that defines an image path to insert into the named notebook
Static Function drawImageInNotebook(String notebookName, String imageText, struct LineContext& context)
	String title, src
	SplitString/E="<IgorImage>\[(.*)\]\((.*)\)</IgorImage>" imageText, title, src
	
	// Figure out if this is a full path or relative path compared to the markdown file we're parsing
	NewPath/Z/O/Q imagePath, src
	if (V_flag != 0)
		// Path doesn't exist to the image, might be a relative path
		// All relative paths assume the image is located within a folder
		// named MD_images that is within the same folder as the
		// .ihf.md file.

		src = ReplaceString("/", src, ":")

		GetFileFolderInfo/P=mdFolderPath/Q /Z src
		
		if (V_flag == 0 && V_isFile == 1)
			LoadPICT/Q/P=mdFolderPath/O src, theImage
			
			Variable width = NumberByKey("WIDTH", S_info, ":", ";")
			Variable height = NumberByKey("HEIGHT", S_info, ":", ";")
			
			Variable fractionOfDoc = width / (ScreenResolution * 6.5)
			if (fractionOfDoc > 1)
				if (width/height > 1.5)
					// landscape
					fractionOfDoc = 1/fractionOfDoc
				else
					// portrait
					fractionOfDoc = 0.75 / fractionOfDoc
				endif
				
			elseif (fractionOfDoc > 0.75) 
				fractionofDoc = 0.75/fractionOfDoc
			elseif (fractionOfDoc > 0.5) 
				fractionofDoc = 0.5/fractionOfDoc
			else
				fractionOfDoc = 1
			endif
			src = S_Path
		else
			Notebook $notebookName, margins = {points(context.leftMargin), points(context.leftMargin), points(6.5)}
			Notebook $notebookName, text = "⚠️⚠️⚠️ Couldn't find the image: " + src + "⚠️⚠️⚠️"
			
			// Print a warning to stderr
			String msg
			sprintf msg,"Couldn't find the image: %s\n",src 
			print msg 
			fprintf -2, msg
			return 0
		endif
	endif

	if (context.isFirstElementInLine)
		if (context.isList)
			Notebook $notebookName margins = {points(context.listLeft[context.listDepth]), points(context.listLeft[context.listDepth]), points(12)}
		else
			setMarginForOperationContext(notebookName, context)
		endif
	endif

	Variable alignVCenter = 0.5 * NumberByKey("HEIGHT", S_info, ":", ";") * (fractionofDoc/100) / (ScreenResolution/ notebookDPI)
	
	MeasureStyledText/W=$notebookName/F=(baseFont)/SIZE=(context.textFormat.fsize) "M"
	alignVCenter -= V_descent
	
	Notebook $notebookName, scaling = {fractionofDoc, fractionofDoc}, insertPicture = {$title, $"", src, 0}
	Notebook $notebookName, selection = {startOfPrevChar, endOfParagraph}, vOffset = alignVCenter
	Notebook $notebookName, selection = {endOfParagraph, endOfParagraph}, vOffset = 0
					
	context.isFirstElementInLine = 0
End

// Draws the inline code defined by codeText in the named notebook
//
// notebookName		: Name of the notebook
// codeText			: Text to insert into the notebook as inline Igor code
// doHighlight		: Set to 1 if you want syntax highlighting turned on (only relevant for FencedCode and CodeSpan)
Static Function drawInlineCodeInNotebook(String notebookName, String codeText, struct LineContext& context)
	String code
	SplitString/E="<IgorCode>(.*)</IgorCode>" codeText, code	
	GetSelection notebook, $notebookName, 1
	Notebook $notebookName, textRGB = (0x5000,0x5000,0x5000), fStyle = 1, vOffset = 0, font = baseCodeFont, text = code
	Notebook $notebookName, selection={endOfFile, endOfFile}, fStyle = 0, textRGB=(0,0,0), font = baseFont
	
	context.isFirstElementInLine = 0
End

// Draws the bold text defined by boldText in the named notebook
//
// notebookName		: Name of the notebook
// boldText			: Text to insert into the notebook as a bold text
Static Function drawBoldTextInNotebook(String notebookName, String boldText, struct LineContext& context)
	String emphasisText
	SplitString/E="<IgorBold>(.*)</IgorBold>" boldText, emphasisText
	
	context.textFormat.format = context.textFormat.format | 1 // add bold attribute
	
	Variable startPos = 0
	Variable endPos = 0
	String remainingText = emphasisText
	
	// This loop draws the bold text element, but also any additional 'emphasis' formats that
	// are nested inside it. This is done so that bold italic text can be rendered correctly
	do
		Variable whichElement = findNextElementLocation(remainingText, startPos, endPos)
		
		if (whichElement != NoElement)
			// Draw up until the nested element
			GetSelection notebook, $notebookName, 1
			drawTextInContext(notebookName, remainingText[0, startPos - 1], context)
			Notebook $notebookName,fStyle = 0
			
			// Draw the nested element recursively
			drawElementInNotebook(notebookName, whichElement, remainingText[startPos, endPos], context)
			remainingText = remainingText[endPos + 1, inf]
		else
			// Draw the rest of the element
			GetSelection notebook, $notebookName, 1
			drawTextInContext(notebookName, remainingText, context)
			Notebook $notebookName,fStyle = 0
		endif
	while (whichElement != NoElement)
	
	// Remove bold format from context
	context.textFormat.format = context.textFormat.format &~ 1
End

// Draws the italic text defined by italicText in the named notebook
//
// notebookName		: Name of the notebook
// italicText		: Text to insert into the notebook as a italic text
Static Function drawItalicTextInNotebook(String notebookName, String italicText, struct LineContext& context)
	String emphasisText
	SplitString/E="<IgorItalic>(.*)</IgorItalic>" italicText, emphasisText
		
	context.textFormat.format = context.textFormat.format | 2 // add italic attribute
	
	Variable startPos = 0
	Variable endPos = 0	
	String remainingText = emphasisText
	
	// This loop draws the bold text element, but also any additional 'emphasis' formats that
	// are nested inside it. This is done so that bold italic text can be rendered correctly
	do
		Variable whichElement = findNextElementLocation(remainingText, startPos, endPos)
		
		if (whichElement != NoElement)
			// Draw up until the nested element
			GetSelection notebook, $notebookName, 1
			drawTextInContext(notebookName, remainingText[0, startPos - 1], context)
			
			// Draw the nested element recursively
			drawElementInNotebook(notebookName, whichElement, remainingText[startPos, endPos], context)
			remainingText = remainingText[endPos + 1, inf]
			
		else
			// Draw the rest of the element
			GetSelection notebook, $notebookName, 1
			drawTextInContext(notebookName, remainingText, context)
		endif
	while (whichElement != NoElement)
	
	// Remove italic format from context
	context.textFormat.format = context.textFormat.format &~ 2
End

// Inserts nLines of vertical padding, where each line is 0.5 line height
//
// notebookName		: Name of the notebook
// nLines			: # of lines of padding to insert
Static Function insertVerticalPadding(String notebookName, Variable nLines)
	Notebook $notebookName, ruler = Padding
	Notebook $notebookName, text = ReplicateString("\n", nLines)
End


Static Function ensureEmptyLine(String notebookName)
	// Insert an extra new line if we aren't at the beginning of a line
	GetSelection notebook, $notebookName, 1
	if (V_startPos != 0)
		Notebook $notebookName, text = "\n"
	endif
End

// Draws all of the elements in the line.
//
// Note, there may be multiple element types in the line, like bold/italic text,
// links, or images. All of these inline elements have to be detected using our
// tag system. For example, all help links will be bracketed by <IgorLink>Help link</IgorLink>
// 
// This function basically iterates through the line from element to element, drawing each
// of them to the notebook one at a time.
//
// notebookName		: Name of the notebook
// line				: Text to insert into the notebook
// isIndented		: Truth that the line should be indented
// doHighlight		: Set to 1 if you want syntax highlighting turned on (only relevant for FencedCode and CodeSpan)
// isTable			: Optional. Set to 1 if this is being called on a paragraph that is inside a table.
// tableColumn		: Optional. Set to the table column being drawn if the paragraph is inside a table.
// isList			: Optional. Set to 1 if this is being called on a paragraph that is inside a list.
Static Function drawParagraphElements(String notebookName, String line, Variable isIndented, struct LineContext& context)
	Variable startPos = 0
	Variable endPos = 0
	Variable lastDrawnPosition = 0
	Variable searchStartPos = startPos
	
	// Replace all newlines with a space, but only if it isn't a code block or table,
	// which both need to keep their newline formatting
	if (!context.isCodeBlock && !context.isTable && !context.isQuote)
		line = ReplaceString("\r", line, " ")
		line = ReplaceString("\n", line, " ")
	endif
		
	NVAR insideOperation = root:insideOperation
	if (isIndented)
		Notebook $notebookName ruler = IndentedParagraph
	elseif (!context.isList && !context.isTable && !context.isQuote)
	
		if (insideOperation)
			Notebook $notebookName ruler = IndentedParagraph
		else
			Notebook $notebookName ruler = Paragraph
		endif
		setMarginForOperationContext(notebookName, context)
	endif
	
	do
		Variable whichElement = findNextElementLocation(line, startPos, endPos, isTable = context.isTable)
		if (whichElement == NoElement)
			break
		endif
		
		// Draws the text up to the location of the next element
		if (context.isList && \
			!context.isTable && !context.isQuote)
			if (context.isListParagraph)
				Notebook $notebookName ruler = ListParagraph
				Notebook $notebookName margins = {points(context.listLeft[context.listDepth]), points(context.listLeft[context.listDepth]), points(6.5)}
			endif
		endif
		
		if (startPos > searchStartPos)
			drawTextInContext(notebookName, line[searchStartPos, startPos - 1], context)
		endif
		
		String elementText = line[startPos, endPos]
		drawElementInNotebook(notebookName, whichElement, elementText, context)
		
		// If a line break was just drawn, it means any list item that it belongs to
		// is now going to be in the category of 'ListParagraph' as opposed to the main list item.
		if (whichElement == LineBreakElement)
			context.isListParagraph = 1
		endif
		
		startPos = endPos + 1
		searchStartPos = startPos
		lastDrawnPosition = endPos
	while(1)
	
	// Draw any remaining characters in the line before the final newline
	if (lastDrawnPosition == 0 || lastDrawnPosition < strlen(line) - 1)
		lastDrawnPosition = (lastDrawnPosition == 0) ? 0 : lastDrawnPosition + 1
		
		if (context.isList && \
			!context.isTable && !context.isQuote)
			if (context.isListParagraph)
				Notebook $notebookName ruler = ListParagraph
				Notebook $notebookName margins = {points(context.listLeft[context.listDepth]), points(context.listLeft[context.listDepth]), points(6.5)}
			endif
		endif
	
		drawTextInContext(notebookName, line[lastDrawnPosition, inf], context)
	endif
End


// Draws a header element
//
// notebookName		: Name of the notebook
// headerText		: Text to insert into the notebook as a header
// level			: Header level, ('H1', 'H2', etc.)
Static Function drawHeader(String notebookName, String headerText, String level, struct LineContext& context)
	
	NVAR nextLineIsOperation = root:nextLineIsOperation
	NVAR nextLineIsIndentedSubtopic = root:nextLineIsIndentedSubtopic
	NVAR insideOperation = root:insideOperation

	NVAR nextLineIsMethod = root:nextLineIsMethod
	NVAR nextLineIsOverload = root:nextLineIsOverload
	NVAR nextLineIsIgorOverload = root:nextLineIsIgorOverload
	NVAR insideMethod = root:insideMethod
	NVAR nextLineIsIgorOperator = root:nextLineIsIgorOperator
	
	// Headers are never colored
	Notebook $notebookName, textRGB = (0, 0, 0)
	
	strswitch (level)
		case "H1":
			Notebook $notebookName, ruler = Topic
			Notebook $notebookName, fSize = baseFontSize + 2, fStyle = 1	 // bold only
			Notebook $notebookName, text = "•"
			Notebook $notebookName, ruler = Topic
			Notebook $notebookName, fStyle = 1 | 4	 // bold and underlined
			Notebook $notebookName, text = "\t" + headerText
			
			context.leftMargin = 3/16
			
			insideOperation = 0
			insideMethod = 0
			break
		case "H2":
			// Special treatment, since this is the subtopic header. Sometimes subtopics
			// require more specific formatting, like in Igor Reference, all of the operations
			// only have the operation in bold but not the entire operation signature. This isn't
			// the case for subtopics in other files. Thus, we support markdown comments that can
			// be placed directly above the subtopic line to indicate the context:
			// <-- IgorCommand -->			: indicates we're going to draw an Igor Operation/Function
			// <-- PythonMethod -->			: indicates we're going to draw a Python method
			// <-- PythonMethodOverload -->	: indicates we're going to draw a Python method overload.
			// <-- IgorOperator --> 		: indicates we're going to draw an Igor operator (which isn't underlined as a subtopic)
			
			Notebook $notebookName, ruler = Subtopic
			
			if (nextLineIsOperation || nextLineIsIgorOperator || nextLineIsIgorOverload)
				String operation, signature
				SplitString/E="(^[\w-#]+)(\b.*)" headerText, operation, signature
				
				if (!strlen(operation))
					// Use the headerText instead
					operation = headerText
				endif

				Variable styleFlags = (nextLineIsIgorOperator) ? 1 : (1 | 4)
				Notebook $notebookName, fStyle = styleFlags, text = operation
				
				if (nextLineIsIgorOverload)
					Notebook $notebookName, spacing = {6, 0, 1}
				endif
				
				do
					String term, before, after
					SplitString/E="([^[:alnum:]_]*)?([[:alnum:]_]+)?([^[:alnum:]_].*)?" signature, before, term, after
					
					if (strlen(before))
						Notebook $notebookName, fStyle = 0, text = before
					endif
					
					if (strlen(term))
						Variable style = (!CmpStr(before[strlen(before) - 1],"/")) ? 0 : 2
						Notebook $notebookName, fStyle = style, text = term
					else
						// If no term, we're at the end of the signature
						Notebook $notebookName, fStyle = 0, text = after
						break
					endif
					
					signature = after
					
					if (!strlen(after))
						break
					endif
				while (1)
				
				
				insideOperation = 1
			elseif (nextLineIsMethod)
				String method, returnType
				SplitString/E="(^[\w\.]+)\s*\((.*)\)(\s*→\s*.*)?" headerText, method, signature, returnType
				Notebook $notebookName, fStyle = 1, text = method
				Notebook $notebookName, fStyle = 0, text = " ("
				Notebook $notebookName, fStyle = 2, text = signature
				Notebook $notebookName, fStyle = 0, text = ")"
				Notebook $notebookName, fStyle = 2, text = returnType
				Notebook $notebookName, fStyle = 0
				insideMethod = 1
			elseif (nextLineIsOverload)
				String overloadMethod
				SplitString/E="(^[\w\.]+)\s*\((.*)\)(\s*→\s*.*)?" headerText, overloadMethod, signature, returnType
				Notebook $notebookName, spacing = {6, 0, 1}
				Notebook $notebookName, fStyle = 1, text = overloadMethod
				Notebook $notebookName, fStyle = 0, text = " ("
				Notebook $notebookName, fStyle = 2, text = signature
				Notebook $notebookName, fStyle = 0, text = ")"
				Notebook $notebookName, fStyle = 2, text = returnType
				Notebook $notebookName, fStyle = 0
				insideMethod = 1
			elseif (nextLineIsIndentedSubtopic)
				Notebook $notebookName, text = headerText
				insideOperation = 1
				insideMethod = 0
			else
				Notebook $notebookName, text = headerText
				insideOperation = 0
				insideMethod = 0
			endif
			
			if (insideOperation)
				context.leftMargin = 5/16
			else
				context.leftMargin = 3/16
			endif
			break
		case "H3":
		case "H4":
			Variable startPos = 0, endPos = 0
			Variable whichElement = findNextElementLocation(headerText, startPos, endPos)
			Variable isItalic = (whichElement == ItalicElement) ? 1 : 0

			
			// The indentation rules are slightly adjusted depending on the context
			Notebook $notebookName, ruler = $level
			if (insideOperation || insideMethod)
				context.leftMargin = 5/16
				Notebook $notebookName, margins = {points(context.leftMargin), points(context.leftMargin), points(6.5)}, fSize = baseFontSize
			else
				context.leftMargin = 3/16
				Notebook $notebookName, margins = {points(context.leftMargin), points(context.leftMargin), points(6.5)}, fSize = baseFontSize
			endif
			
			if (isItalic)
				String emphasisText
				SplitString/E="<IgorItalic>(.*)</IgorItalic>" headerText, emphasisText	
				Notebook $notebookName, fstyle = 1 | 2, text = emphasisText
				Notebook $notebookName, fstyle = 1
			else
				Notebook $notebookName, fstyle = 1, text = headerText
			endif	
			
			
			break
		default:
			break
	endswitch
	
	Notebook $notebookName, fSize = baseFontSize
End

// Returns the length of the longest row in a table column
//
// tableText	: Text defining the table
// nRows		: Number of rows in the table
// whichCol		: Column number that we're analyzing
Static Function longestTableRowWidth(String tableText, Variable nRows, Variable whichCol, struct TableStats& tableStats)
	Variable i
	
	Variable maxColWidth = 0
	Variable maxNestedColWidth = 0
	
	Variable fontSizePixels = baseFontSize * ScreenResolution/72
	
	Variable inNestedRun = 0
	Variable nestedRunIndex = 0
	Variable nestedRunLength = 0
	
	for (i = 0; i < nRows; ++i)
		String rowText = StringFromList(i, tableText, "\n")
		String firstColumnText = StringFromList(whichCol, rowText, "<TableDiv>")
		
		if (whichCol < tableStats.nCols)
			// If there isn't anything in the column to the right, we can ignore this row
			// for the width calculation.
			String nextColumnText = StringFromList(whichCol + 1, rowText, "<TableDiv>")
			if (!strlen(nextColumnText))
				continue
			endif
		endif
			
		firstColumnText = ReplaceString("Bold>",firstColumnText, "")
		firstColumnText = ReplaceString("Italic>",firstColumnText, "")
		firstColumnText = ReplaceString("Code>",firstColumnText, "")
		firstColumnText = ReplaceString("Image>",firstColumnText, "")
		firstColumnText = ReplaceString("Link>",firstColumnText, "")
		firstColumnText = ReplaceString("<Igor",firstColumnText, "")
		firstColumnText = ReplaceString("<sub>",firstColumnText, "")
		firstColumnText = ReplaceString("</sub>",firstColumnText, "")
		firstColumnText = ReplaceString("<sup>",firstColumnText, "")
		firstColumnText = ReplaceString("</sup>",firstColumnText, "")
		firstColumnText = ReplaceString("</Igor",firstColumnText, "")
		
		String before="", middle="", after=""
		SplitString/E="(.*)<span.*>(.*)<\/span>(.*)" firstColumnText, before, middle, after
		
		if (strlen(S_Value))
			firstColumnText = before + middle + after
		endif
			
		// Is there a nested column in here?
		String nestedColStart = StringFromList(0, firstColumnText, "::")
		String nestedColEnd = StringFromList(1, firstColumnText, "::")
		
		Variable nestedColWidth = 0
		Variable width = 0
		
		// If there is a nested column, we use the starting text to determine where the tab stop is
		if (strlen(nestedColEnd))
			nestedColWidth = FontSizeStringWidth(baseFont, fontSizePixels, 0, nestedColStart) / ScreenResolution
			width = FontSizeStringWidth(baseFont, fontSizePixels, 0, nestedColStart + "\t" + nestedColEnd + "\t") / ScreenResolution
			
			if (whichCol == tableStats.nCols)
				tableStats.nestedColRows += num2str(i) + ";"
				
				inNestedRun = 1
				nestedRunLength++
			endif
		else
			if (inNestedRun)
				// Fill all rows from the run with the max width of that run
				Variable j
				for (j = nestedRunIndex; j < nestedRunIndex + nestedRunLength; ++j)
					tableStats.nestedColWidth[j] = maxNestedColWidth
				endfor
				
				nestedRunIndex += nestedRunLength
			endif
			
			
			width = FontSizeStringWidth(baseFont, fontSizePixels, 0, firstColumnText + "\t") / ScreenResolution
			inNestedRun = 0
			maxNestedColWidth = 0
			nestedRunLength = 0
		endif
		
		// Round width to the nearest 1/10"
		Variable roundedWidth = ( (floor(width) * 10) + ceil(mod(width, 1) * 10) ) / 10
		Variable roundedNestedColWidth = ( (floor(nestedColWidth) * 10) + ceil(mod(nestedColWidth, 1) * 10) ) / 10
		
		maxNestedColWidth = max(maxNestedColWidth, roundedNestedColWidth)
		maxColWidth = max(maxColWidth, roundedWidth)
	endfor
	
	// If the nested row was the last row, we need to fill the structure here
	if (inNestedRun)
		// Fill all rows from the run with the max width of that run
		for (j = nestedRunIndex; j < nestedRunIndex + nestedRunLength; ++j)
			tableStats.nestedColWidth[j] = maxNestedColWidth
		endfor
		
		nestedRunIndex += nestedRunLength
	endif
	
	if (nestedRunIndex >= maxNumNestedRows)
		String msg
		sprintf msg,"Reached the maximum number of nested rows in this table! %d were required.", nestedRunIndex 
		print msg 
		fprintf -2, msg
	endif
	
	return maxColWidth
End


// Analyzes the lines in a table to determine row/col counts and widths
//
// tableText	: Text defining the table
// tableStats	: Output structure holding information about the table
Static Function analyzeTable(String tableText, Struct TableStats& tableStats)
	Variable nRows = ItemsInList(tableText,"\n")
	Variable i, j, nCols
	Variable maxCols = 0
	
	// Clear the structure
	for (i = 0; i < maxNumTableCols; i++)
		tableStats.colWidth[i] = 0
		tableStats.nestedColRows = ""
	endfor
	
	for (i = 0; i < maxNumNestedRows; ++i)
		tableStats.nestedColWidth[i] = 0
	endfor
	
	tableStats.nestedColRows = ""
	tableStats.cellIsNested = 0
	tableStats.extraBuffer = 0
	tableStats.tableCellIsPreformat = 0
	
	for (i = 0; i < nRows; ++i)
		String rowText = StringFromList(i, tableText, "\n")
		
		nCols = ItemsInList(rowText, "<TableDiv>") - 1
		tableStats.nCols = max(nCols, tableStats.nCols)
	endfor
	
	tableStats.nCols = min(tableStats.nCols, maxNumTableCols)
	
	// We start at 1 because the first character should always be a "<TableDiv>", so 
	// we'll be processing an empty string
	for (i = 1; i < tableStats.nCols + 1; ++i)
		// Add a 4/16" buffer between columns, seems to look decent
		Variable width = longestTableRowWidth(tableText, nRows, i, tableStats)
		
		width += (4/16)
		
		if (i == 1)
			tableStats.colWidth[i - 1] = width
		else
			// Accumulate the widths from the previous column
			tableStats.colWidth[i - 1] = tableStats.colWidth[i - 2] + width
		endif
	endfor
	
	Variable nNestedRows = ItemSInList(tableStats.nestedColRows, ";")
	for (i = 0; i < nNestedRows; ++i)
		Variable whichRow = str2num(StringFromList(i, tableStats.nestedColRows, ";"))
		Variable widthUpToTheColumn = tableStats.colWidth[tableStats.nCols - 2]
		tableStats.nestedColWidth[i] += widthUpToTheColumn + (2/16)
	endfor

End

// Utility function for determining if a given cell in a table requires nesting
static function setTableCellIsNested(Variable row, Variable col, struct TableStats& stats)
	// Must be in the last column
	if (col < stats.nCols -1)
		stats.cellIsNested = 0
		return 0
	endif
	
	Variable rowRequiresNesting = WhichListItem(num2str(row), stats.nestedColRows, ";")
	stats.cellIsNested = (rowRequiresNesting != -1)	
end

static function preparePossiblePreformatBlock(String& text, struct LineContext& context)
	String possibleCode
	SplitString/E = "<pre>(.*)</pre>" text, possibleCode

	if (strlen(possibleCode))
		// Add a newline on the end if it isn't there already
		text = RemoveEnding(possibleCode, "\n") + "\n" 
		return 1
	endif
	
	return 0
end

// Convenience function for setting the margin positions of a table row
// notebookName	: Name of the notebook
// row			: Row in the table being set
// col			: Column in the table being set
// context		: Current context of the line
// stats		: Table statistics, which includes the analyzed table data (widths of columns, etc.)
static function setTableMargins(String notebookName, Variable row, Variable col, struct LineContext& context, struct TableStats& stats)
	
	Variable rightMargin = (stats.tableCellIsPreformat) ? 12 : 6.5

	if (stats.cellIsNested)
		// This is the index into stats.nestedColWidth
		Variable index = WhichListItem(num2str(row), stats.nestedColRows, ";")
				
		// If the cell is nested, we need
		if (context.isList)
			// Obey the list margins
			Notebook $notebookName margins = {points(context.listLeft[context.listDepth] + stats.extraBuffer), \
											points(context.listLeft[context.listDepth] + stats.nestedColWidth[index] + stats.extraBuffer), points(rightMargin)}
		else
			Notebook $notebookName margins = {points(context.leftMargin + stats.extraBuffer), points(context.leftMargin + stats.nestedColWidth[index] + stats.extraBuffer), \
			  								points(rightMargin)}
		endif
	else
		if (context.isList)
			// Obey the list margins
			Notebook $notebookName margins = {points(context.listLeft[context.listDepth] + stats.extraBuffer), \
											points(context.listLeft[context.listDepth] + stats.colWidth[col-1] + stats.extraBuffer), points(rightMargin)}
		else
			Notebook $notebookName margins = {points(context.leftMargin + stats.extraBuffer), \ 
											points(context.leftMargin + stats.colWidth[col-1] + stats.extraBuffer),  points(rightMargin)}
		endif
	endif
end

// Convenience function for setting the tab stop positions of a table row
// notebookName	: Name of the notebook
// row			: Row in the table being set
// col			: Column in the table being set
// context		: Current context of the line
// stats		: Table statistics, which includes the analyzed table data (widths of columns, etc.)
static function setTableTabs(String notebookName, Variable row, Variable col, struct LineContext& context, struct TableStats& stats)
	if (stats.cellIsNested)
		
		// This is the index into stats.nestedColWidth
		Variable index = WhichListItem(num2str(row), stats.nestedColRows, ";")
		
		// If the cell is nested, it means we need to add in the additional tab stop defining the nested column.
		// Compared to the 'else' code block below this, everything should be identical except for the additional
		// tab stop.
		if (stats.nCols == 2)
			Notebook $notebookName tabs = { points(context.leftMargin + stats.colWidth[0] + stats.extraBuffer), points(context.leftMargin + stats.nestedColWidth[index] + stats.extraBuffer)}
		elseif (stats.nCols == 3)
			Notebook $notebookName tabs = { points(context.leftMargin + stats.colWidth[0] + stats.extraBuffer), points(context.leftMargin + stats.colWidth[1] + stats.extraBuffer), \
											points(context.leftMargin + stats.nestedColWidth[index] + stats.extraBuffer)}
		elseif (stats.nCols == 4)
			Notebook $notebookName tabs = { points(context.leftMargin + stats.colWidth[0] + stats.extraBuffer), points(context.leftMargin + stats.colWidth[1] + stats.extraBuffer), \
											points(context.leftMargin + stats.colWidth[2] + stats.extraBuffer), points(context.leftMargin + stats.nestedColWidth[index] + stats.extraBuffer)}
		elseif (stats.nCols == 5)
			Notebook $notebookName tabs = { points(context.leftMargin + stats.colWidth[0] + stats.extraBuffer), points(context.leftMargin + stats.colWidth[1] + stats.extraBuffer), \
											points(context.leftMargin + stats.colWidth[2] + stats.extraBuffer), points(context.leftMargin + stats.colWidth[3] + stats.extraBuffer), \
											points(context.leftMargin + stats.nestedColWidth[index] + stats.extraBuffer)}
		elseif (stats.nCols == 6)
			Notebook $notebookName tabs = { points(context.leftMargin + stats.colWidth[0] + stats.extraBuffer), points(context.leftMargin + stats.colWidth[1] + stats.extraBuffer), \
											points(context.leftMargin + stats.colWidth[2] + stats.extraBuffer), points(context.leftMargin + stats.colWidth[3] + stats.extraBuffer), \
											points(context.leftMargin + stats.colWidth[4] + stats.extraBuffer), points(context.leftMargin + stats.nestedColWidth[index] + stats.extraBuffer)}
		elseif (stats.nCols == 7)
			Notebook $notebookName tabs = { points(context.leftMargin + stats.colWidth[0] + stats.extraBuffer), points(context.leftMargin + stats.colWidth[1] + stats.extraBuffer), \
											points(context.leftMargin + stats.colWidth[2] + stats.extraBuffer), points(context.leftMargin + stats.colWidth[3] + stats.extraBuffer), \
											points(context.leftMargin + stats.colWidth[4] + stats.extraBuffer), points(context.leftMargin + stats.colWidth[5] + stats.extraBuffer), \
											points(context.leftMargin + stats.nestedColWidth[index] + stats.extraBuffer)}
		elseif (stats.nCols == 8)
			Notebook $notebookName tabs = { points(context.leftMargin + stats.colWidth[0] + stats.extraBuffer), points(context.leftMargin + stats.colWidth[1] + stats.extraBuffer), \
											points(context.leftMargin + stats.colWidth[2] + stats.extraBuffer), points(context.leftMargin + stats.colWidth[3] + stats.extraBuffer), \
											points(context.leftMargin + stats.colWidth[4] + stats.extraBuffer), points(context.leftMargin + stats.colWidth[5] + stats.extraBuffer), \
											points(context.leftMargin + stats.colWidth[6] + stats.extraBuffer), points(context.leftMargin + stats.nestedColWidth[index] + stats.extraBuffer)}
		endif
	else
		if (stats.nCols == 2)
			Notebook $notebookName tabs = { points(context.leftMargin + stats.colWidth[0] + stats.extraBuffer)}
		elseif (stats.nCols == 3)
			Notebook $notebookName tabs = { points(context.leftMargin + stats.colWidth[0] + stats.extraBuffer), points(context.leftMargin + stats.colWidth[1] + stats.extraBuffer)}
		elseif (stats.nCols == 4)
			Notebook $notebookName tabs = { points(context.leftMargin + stats.colWidth[0] + stats.extraBuffer), points(context.leftMargin + stats.colWidth[1] + stats.extraBuffer), \
											points(context.leftMargin + stats.colWidth[2] + stats.extraBuffer)}
		elseif (stats.nCols == 5)
			Notebook $notebookName tabs = { points(context.leftMargin + stats.colWidth[0] + stats.extraBuffer), points(context.leftMargin + stats.colWidth[1] + stats.extraBuffer), \
											points(context.leftMargin + stats.colWidth[2] + stats.extraBuffer), points(context.leftMargin + stats.colWidth[3] + stats.extraBuffer)}
		elseif (stats.nCols == 6)
			Notebook $notebookName tabs = { points(context.leftMargin + stats.colWidth[0] + stats.extraBuffer), points(context.leftMargin + stats.colWidth[1] + stats.extraBuffer), \
											points(context.leftMargin + stats.colWidth[2] + stats.extraBuffer), points(context.leftMargin + stats.colWidth[3] + stats.extraBuffer), \
											points(context.leftMargin + stats.colWidth[4] + stats.extraBuffer)}
		elseif (stats.nCols == 7)
			Notebook $notebookName tabs = { points(context.leftMargin + stats.colWidth[0] + stats.extraBuffer), points(context.leftMargin + stats.colWidth[1] + stats.extraBuffer), \
											points(context.leftMargin + stats.colWidth[2] + stats.extraBuffer), points(context.leftMargin + stats.colWidth[3] + stats.extraBuffer), \
											points(context.leftMargin + stats.colWidth[4] + stats.extraBuffer), points(context.leftMargin + stats.colWidth[5] + stats.extraBuffer)}
		elseif (stats.nCols == 8)
			Notebook $notebookName tabs = { points(context.leftMargin + stats.colWidth[0] + stats.extraBuffer), points(context.leftMargin + stats.colWidth[1] + stats.extraBuffer), \
											points(context.leftMargin + stats.colWidth[2] + stats.extraBuffer), points(context.leftMargin + stats.colWidth[3] + stats.extraBuffer), \
											points(context.leftMargin + stats.colWidth[4] + stats.extraBuffer), points(context.leftMargin + stats.colWidth[5] + stats.extraBuffer), \
											points(context.leftMargin + stats.colWidth[6] + stats.extraBuffer)}				
		endif
	endif
end


// Draws the elements of a markdown table
//
// notebookName	: Name of the notebook
// tableText	: Text that defines the table
Static Function drawTableElements(String notebookName, String tableText, struct LineContext& context)
	Variable nRows = ItemsInList(tableText,"\n")
	String tab = ""
	
	ensureEmptyLine(notebookName)

	context.isTable = 1
	if (context.isList)
		context.leftMargin = context.listLeft[context.listDepth]
	endif
		
	Struct tableStats tableStats
	analyzeTable(tableText, tableStats)
	
	Notebook $notebookName, ruler = Table

	Variable row, col
	for (row = 0; row < nRows; ++row)

		String rowText = StringFromList(row, tableText, "\n")
		
		tableStats.extraBuffer = 0
		tableStats.tableCellIsPreformat = 0
			
		// If there is any pre-format tag in this entire row, we treat it
		// as if the preformat text is the only thing in the row. Otherwise,
		// it won't be able to render correctly since preformat (Igor code block)
		// is defined by the ruler name of the entire line
		String preformatText = rowText
		if (preparePossiblePreformatBlock(preformatText, context))
			tableStats.extraBuffer = 1/16
			tableStats.tableCellIsPreformat = 1
			
			// Insert padding
			insertVerticalPadding(notebookName, 1)
			
			Notebook $notebookName, ruler = Table
		endif
			
		
		Variable nCols = ItemsInList(rowText, "<TableDiv>")
		for (col = 0; col < nCols; ++col)
			
			String cellText = StringFromList(col + 1, rowText, "<TableDiv>")
			if (strlen(cellText) == 0)
				if (col > 0 && col < nCols - 1)
					Notebook $notebookName, text = "\t", fStyle = 0
				endif
				continue			
			endif
		
			// A nested cell is in the last column of the table, and includes text of the format:
			// Term::Definition, where we treat the 'Term' and 'Definition' as subcolumns.
			setTableCellIsNested(row, col, tableStats)

			if (tableStats.tableCellIsPreformat)
				cellText = preformatText
				Notebook $notebookName ruler = Code_Igor
				Notebook $notebookName fsize = baseFontSize
			endif
	
			if (col == 0)
				tab = ""
				Variable rightMargin = (tableStats.tableCellIsPreformat) ? 12 : 6.5
				Notebook $notebookName margins = {points(context.leftMargin), points(context.leftMargin),  points(rightMargin)}
			else
				
				// The margins will be set up so that the 'left indent' defines the left point of the table,
				// and the 'first line indent' defines the beginning of the final column. Columns that are interior
				// to these are defined by the tab stops in between.
				setTableMargins(notebookName, row, col, context, tableStats)	
			
				// Tab stops define the interior column positions, but can also define
				// where nested columns go.
				//
				// A nested column can only be in the last column of the table, and includes text of the format:
				// Term::Definition, where we treat the 'Term' and 'Definition' as subcolumns. The position
				// of the subcolumn is defined by an addition tab stop.
				setTableTabs(notebookName, row, col, context, tableStats)
												
				tab = "\t"
			endif 
			
			Notebook $notebookName, text =  tab, fStyle = 0
			
			context.tableColumn = col
			
			// Handle any explicit line breaks that exist in the table cell.
			// These will be drawn 
			Variable whichBreak
			for (whichBreak = 1;whichBreak < ItemsInList(cellText, "<br>"); ++whichBreak)
				String subline = StringFromList(whichBreak, cellText, "<br>")
				cellText = ReplaceString(subline, cellText, ReplicateString("\t", context.tableColumn) + subline)			
			endfor
			
			if (tableStats.cellIsNested)
				cellText = ReplaceString("::", cellText, "\t")
			endif
	
			drawParagraphElements(notebookName, cellText, 0, context)	
			
		endfor
		
		// Insert padding at end of preformat block (code block)
		if (tableStats.tableCellIsPreformat)
			// This just sets the current line to be a padding ruler size,
			// Since we've already added the newline in the preformat text
			insertVerticalPadding(notebookName, 0)
			Notebook $notebookName, text = "\n"
			Notebook $notebookName, ruler = Table
		else
			Notebook $notebookName, text = "\n"	
		endif

	endfor
	
	insertVerticalPadding(notebookName, 0)
End

// Utility for converting an HTML specified color to rgb, on a 16 bit color scale (0-65535)
// Example:
// '#00ff00'
// will convert to
// red = 0
// green = 65535
// blue = 0
static function HTMLColorTagToRGB(String htmlColor, struct RGBColor& rgb)
	String r, g, b
	SplitString/E="#([[:alnum:]]{2})([[:alnum:]]{2})([[:alnum:]]{2})" htmlColor, r, g, b
	if (!strlen(r) || !strlen(g) || !strlen(b))
		rgb.red = 0
		rgb.green = 0
		rgb.blue = 0
	endif
	
	rgb.red = (str2num("0x" + r) / 255) * 0xffff
	rgb.green = (str2num("0x" + g) / 255) * 0xffff
	rgb.blue = (str2num("0x" + b) / 255) * 0xffff
end

// Utility for converting an rgb specified color in an HTML tag to rgb, on a 16 bit color scale (0-65535)
// Example:
// 'rgb(15, 255, 34)'
// will convert to
// red = 3855
// green = 65535
// blue = 8738
static function RGBColorTagToRGB(String htmlColor, struct RGBColor& rgb)
	String r, g, b
	SplitString/E="rgb\(\s*([[:digit:]]+)\s*,\s*([[:digit:]]+)\s*,\s*([[:digit:]]+)\s*\)" htmlColor, r, g, b
	if (!strlen(r) || !strlen(g) || !strlen(b))
		rgb.red = 0
		rgb.green = 0
		rgb.blue = 0
	endif
	
	rgb.red = (str2num(r) / 255) * 0xffff
	rgb.green = (str2num(g) / 255) * 0xffff
	rgb.blue = (str2num(b) / 255) * 0xffff
end

static Function parseHTMLSpan(String spanText, struct LineContext& context)
	Variable i
	for (i = 0; i < ItemsInList(spanText, ";"); ++i)
		String atrribute = StringFromList(i, spanText, ";")
		String key = TrimString(StringFromList(0, atrribute, ":"))
		String value = TrimString(StringFromList(1, atrribute, ":"))
		
		// Do we support this attribute?
		strswitch(key)
			case "color":
				if (strsearch(value, "#", 0) != -1)
					HTMLColorTagToRGB(value, context.textFormat.rgb)
				elseif (strsearch(value, "rgb", 0) != -1)
					RGBColorTagToRGB(value, context.textFormat.rgb)
				endif
				break
			case "font-size":
				Variable pointSize = str2num(StringFromList(0, value, "pt"))
				context.textFormat.fSize = pointSize
				break
			default:
				// Unsupported!
				return 1
				break
		endswitch
		
	endfor
	
	return 0
end

static function setMarginForOperationContext(String notebookName, struct LineContext& context)
	NVAR insideOperation = root:insideOperation
	NVAR insideMethod = root:insideMethod
	if (insideOperation || insideMethod)
		Notebook $notebookName, margins = {points(5/16), points(5/16), points(6.5)}
	else
		Notebook $notebookName, margins = {points(3/16), points(3/16), points(6.5)}
	endif
end

// Draws the element specified by the HTML tag into the notebook
// Currently the only tag we support is img
//
// notebookName		: Name of the notebook
// htmlText			: Text to insert into the notebook, if we support the HTML tag
static Function drawHTMLBlockElement(String notebookName, String htmlText, struct LineContext& context)
	
	htmlText = ReplaceString("\n", htmlText, "")
	
	NVAR nextLineIsOperation = root:nextLineIsOperation
	nextLineIsOperation = !cmpstr(htmlText, "<!-- IgorCommand -->")
	if (nextLineIsOperation)
		return 0
	endif
	
	NVAR nextLineIsIndentedSubtopic = root:nextLineIsIndentedSubtopic
	nextLineIsIndentedSubtopic = !cmpstr(htmlText, "<!-- IndentedSubtopic -->")
	if (nextLineIsIndentedSubtopic)
		return 0
	endif
	
	NVAR nextLineIsMethod = root:nextLineIsMethod
	nextLineIsMethod = !cmpstr(htmlText, "<!-- PythonMethod -->")
	if (nextLineIsMethod)
		return 0
	endif
	
	NVAR nextLineIsIgorOverload = root:nextLineIsIgorOverload
	nextLineIsIgorOverload = !cmpstr(htmlText, "<!-- IgorOverload -->")
	if (nextLineIsIgorOverload)
		return 0
	endif
	
	NVAR nextLineIsOverload = root:nextLineIsOverload
	nextLineIsOverload = !cmpstr(htmlText, "<!-- PythonMethodOverload -->")
	if (nextLineIsOverload)
		return 0
	endif
	
	NVAR nextLineIsIgorOperator = root:nextLineIsIgorOperator
	nextLineIsIgorOperator = !cmpstr(htmlText, "<!-- IgorOperator -->")
	if (nextLineIsIgorOperator)
		return 0
	endif
	
	// Pattern match to extract the tag type
	String whichTag, body, singleElementTag, theRest
	SplitString/E="(?:^<(\w+)\s*(.*)>$)|(?:^<(\w+)>(.*))" htmlText, whichTag, body, singleElementTag, theRest
	
	if (strlen(singleElementTag) > 0)
		whichTag = singleElementTag
	endif
	
	strswitch (whichTag)
		case "span":
			String attributes
			SplitString/E="style=\"(.*?)\"\s*>" body, attributes
			
			if (!strlen(attributes))
				Notebook $notebookName, text = "⚠️⚠️⚠️ Invalid HTML span! " + htmlText + "⚠️⚠️⚠️"
				break
			endif
			
			Variable err = parseHTMLSpan(attributes, context)
			if (err)
				Notebook $notebookName, text = "⚠️⚠️⚠️ Invalid HTML span! " + htmlText + "⚠️⚠️⚠️"
				break
			endif
			
			SplitString/E="<.*?>(.*?)</span>" htmlText, body
			drawParagraphElements(notebookName, body, 0, context)

			// Reset the context
			context.textFormat.rgb.red = 0
			context.textFormat.rgb.green = 0
			context.textFormat.rgb.blue = 0
			context.textFormat.fSize = baseFontSize
			Notebook $notebookName, textRGB = (0,0,0)
			break
		case "img":
			// Find the 'src'
			String src
			SplitString/E="src=\"(.*?)\"\s*" body, src
			
			if (strlen(src) == 0)
				Print "<img> HTML block doesn't contain a valid 'src' specification:", body
				break
			endif
			
			// Find the 'alt' text, if available
			String title
			SplitString/E="alt=\"(.*?)\"\s*" body, title
			if (strlen(title) == 0)
				title = src
			endif

			// Find the 'width', if available
			String scale
			SplitString/E="width=\"([[:digit:]]+)%\"\s*" body, scale
			if (strlen(scale) == 0)
				scale = "100"
			endif
			
			Variable scaleNum = str2num(scale)

			// Figure out if this is a full path or relative path compared to the markdown file we're parsing
			NewPath/Z/O/Q imagePath, src
			if (V_flag != 0)
				// Path doesn't exist to the image, might be a relative path
				// All relative paths assume the image is located within a folder
				// named MD_images that is within the same folder as the
				// .ihf.md file.
				String dest = ReplaceString("/", src, ":")
				dest = ReplaceString("..", dest, ":")
				
				GetFileFolderInfo/P=mdFolderPath/Q /Z dest
				
				if (V_flag == 0 && V_isFile == 1)
					LoadPICT/Q/P=mdFolderPath/O dest, theImage
					
					if (context.isFirstElementInLine)
						if (context.isList)
							Notebook $notebookName margins = {points(context.listLeft[context.listDepth]), points(context.listLeft[context.listDepth]), points(12)}
						else
							setMarginForOperationContext(notebookName, context)
						endif
					endif

					Variable alignVCenter = 0.5 * NumberByKey("HEIGHT", S_info, ":", ";") * (scaleNum/100) / (ScreenResolution/ notebookDPI)
					
					MeasureStyledText/W=$notebookName/F=(baseFont)/SIZE=(context.textFormat.fsize) "M"
					alignVCenter -= V_descent
					
					Notebook $notebookName, scaling = {scaleNum, scaleNum}, insertPicture = {$title, mdFolderPath, dest, 0}
					Notebook $notebookName, selection = {startOfPrevChar, endOfParagraph}, vOffset = alignVCenter
					Notebook $notebookName, selection = {endOfParagraph, endOfParagraph}, vOffset = 0
				else
					Notebook $notebookName, text = "\n⚠️⚠️⚠️ Couldn't find the image: " + dest + "⚠️⚠️⚠️\n"
				
					// Print a warning to stderr
					String msg
					sprintf msg,"Couldn't find the image: %s\n",dest 
					print msg 
					fprintf -2, msg
					return 0
					
				endif
			else
				Notebook $notebookName, text = "\n⚠️⚠️⚠️ Couldn't find the image: " + dest + "⚠️⚠️⚠️\n"
				
				// Print a warning to stderr
				sprintf msg,"Couldn't find the image: %s\n",dest 
				print msg 
				fprintf -2, msg
				return 0
			endif
			break
		case "sup":
			drawHTMLTagInNotebook(notebookName, htmlText, SuperscriptElement, context)
			break
		case "sub":
			drawHTMLTagInNotebook(notebookName, htmlText, SubscriptElement, context)
			break
		case "br":
			drawHTMLTagInNotebook(notebookName, htmlText, LineBreakElement, context)
			break
		default:
			if (strlen(whichTag))
				Print "HTML block uses a tag that we don't support:", whichTag
			endif
			break
	endswitch
	
	if (strlen(theRest))
		drawParagraphElements(notebookName, theRest, 0, context)		
	endif
	
End

StrConstant noteStr = "[!NOTE]"
StrConstant warningStr = "[!WARNING]"
StrConstant cautionStr = "[!CAUTION]"

// Draws a Quote element, which contains the quote special character and the text below it
//
// notebookName	: Name of the notebook
// line			: Text of the quote, including the quote type specification
// context		: Context of the line
static Function drawQuoteElement(String notebookName, String line, struct LineContext& context)
	ensureEmptyLine(notebookName)
	
	NVAR insideOperation = root:insideOperation
	context.isQuote = 1
	
	Notebook $notebookName, ruler = QuoteHeader
	
	context.textFormat.rgb.red = 0x5000
	context.textFormat.rgb.green = 0x5000
	context.textFormat.rgb.blue = 0x5000
	
	if (context.isList)
		// Obey the list margins
		Notebook $notebookName margins = {points(context.listLeft[context.listDepth] + (1/16) ), \
										points(context.listLeft[context.listDepth] + (1/16) ), points(6.5)}
	elseif (insideOperation)
		Notebook $notebookName, margins = {points(6/16), points(6/16), points(6)}
	else
		Notebook $notebookName, margins = {points(context.leftMargin + (1/16) ), points(context.leftMargin), points(6.5)}
	endif
	
	Variable foundNote = strsearch(line, noteStr, 0)
	if (foundNote != -1)
		Notebook $notebookName, vOffset = -1, specialChar = {7, 0, ""}
		Notebook $notebookName, vOffset = 0, textRGB = (0, 0x6700, 0x9b00), text = " Note\n"
		line = line[1 + foundNote + strlen(noteStr), inf]
	endif
	
	Variable foundWarning = strsearch(line, warningStr, 0)
	if (foundWarning != -1)
		Notebook $notebookName, vOffset = -1, specialChar = {8, 0, ""}
		Notebook $notebookName, vOffset = 0, textRGB = (0xd200, 0x9900, 0x2200), text = " Warning\n"
		line = line[1 + foundWarning + strlen(warningStr), inf]
	endif
	
	Variable foundCaution = strsearch(line, cautionStr, 0)
	if (foundCaution != -1)
		Notebook $notebookName, vOffset = -1, specialChar = {9, 0, ""}
		Notebook $notebookName, vOffset = 0,  textRGB = (0xc400, 0x1d00, 0), text = " Caution\n"
		line = line[1 + foundCaution + strlen(cautionStr), inf]
	endif
	
	Notebook $notebookName, vOffset = 0

	Notebook $notebookName, ruler = Quote
	if (context.isList)
		// Obey the list margins
		Notebook $notebookName margins = {points(context.listLeft[context.listDepth] + (1/16) ), \
										points(context.listLeft[context.listDepth] + (1/16) ), points(6)}
	elseif (insideOperation)
		Notebook $notebookName, margins = {points(6/16), points(6/16), points(6)}
	else
		Notebook $notebookName, margins = {points(context.leftMargin + (1/16) ), points(context.leftMargin + (1/16) ), points(6)}
	endif
	
	drawParagraphElements(notebookName, line, 0, context)
		
	context.textFormat.rgb.red = 0
	context.textFormat.rgb.green = 0
	context.textFormat.rgb.blue = 0
	context.isQuote = 0
	context.isFirstElementInLine = 0
End

static function drawTableCellQuoteElement(String notebookName, String line, struct LineContext& context)
	// Set the color
	context.textFormat.rgb.red = 0x5000
	context.textFormat.rgb.green = 0x5000
	context.textFormat.rgb.blue = 0x5000
	
	Variable foundNote = strsearch(line, noteStr, 0)
	if (foundNote != -1)
		Notebook $notebookName, specialChar = {7, 0, ""}
		Notebook $notebookName, selection = {startOfPrevChar, endOfParagraph}, vOffset = -1
		Notebook $notebookName, selection={endOfFile, endOfFile}, vOffset = 0, textRGB = (0, 0x6700, 0x9b00), text = " Note\n" + ReplicateString("\t", context.tableColumn)
		line = line[foundNote + strlen(noteStr), inf]
	endif
	
	Variable foundWarning = strsearch(line, warningStr, 0)
	if (foundWarning != -1)
		Notebook $notebookName, specialChar = {8, 0, ""}
		Notebook $notebookName, selection = {startOfPrevChar, endOfParagraph}, vOffset = -1
		Notebook $notebookName, selection={endOfFile, endOfFile}, vOffset = 0, textRGB = (0xd200, 0x9900, 0x2200), text = " Warning\n" + ReplicateString("\t", context.tableColumn)
		line = line[foundWarning + strlen(warningStr), inf]
	endif
	
	Variable foundCaution = strsearch(line, cautionStr, 0)
	if (foundCaution != -1)
		Notebook $notebookName, specialChar = {9, 0, ""}
		Notebook $notebookName, selection = {startOfPrevChar, endOfParagraph}, vOffset = -1
		Notebook $notebookName, selection={endOfFile, endOfFile}, vOffset = 0, textRGB = (0xc400, 0x1d00, 0), text = " Caution\n" + ReplicateString("\t", context.tableColumn)
		line = line[foundCaution + strlen(cautionStr), inf]
	endif
	
	Notebook $notebookName, vOffset = 0
	
	line = TrimString(line)
	drawParagraphElements(notebookName, line, 0, context)
	
	// Reset the context
	context.textFormat.rgb.red = 0
	context.textFormat.rgb.green = 0
	context.textFormat.rgb.blue = 0
	context.isQuote = 0
	context.isFirstElementInLine = 0
end

// Draws the code block specified by codeText and language into the notebook
// language is needed so we know how to syntax highlight the text
//
// notebookName		: Name of the notebook
// codeText			: Text to insert into the notebook as a fenced code block
// language			: Language of the code, which ideally will toggle which syntax highlighter is used
// doHighlight		: Set to 1 if you want syntax highlighting turned on
Static Function drawFencedCode(String notebookName, String codeText, String language, struct LineContext& context)
	
	// Insert an extra new line if we aren't at the beginning of a line
	GetSelection notebook, $notebookName, 1
	if (V_startPos != 0)
		Notebook $notebookName, text = "\n"
	endif
		
	insertVerticalPadding(notebookName, 1)
	
	strswitch(language)
		case "igor":
			Notebook $notebookName, ruler = Code_Igor
			break
		case "python":
			Notebook $notebookName, ruler = Code_Python
			break
		default:
			Notebook $notebookName, ruler = Code_Other
			Notebook $notebookName, textRGB = (0x5000,0x5000,0x5000)
	endswitch
	
		
	NVAR insideOperation = root:insideOperation
	
	if (context.isList)
		Variable leftMarginPoints = points(context.listLeft[context.listDepth]) + points(1/16) 
		Notebook $notebookName margins = {leftMarginPoints, leftMarginPoints, points(12)}
		Notebook $notebookName, tabs = {leftMarginPoints, leftMarginPoints + points(3/16), leftMarginPoints + points(3/16) * 2, leftMarginPoints + points(3/16) * 3, leftMarginPoints + points(3/16) * 4}

	elseif(insideOperation)
		leftMarginPoints = points(5/16 + 1/16)
		Notebook $notebookName margins = {leftMarginPoints, points(context.listLeft[context.listDepth]) + points(2/16), points(12)}
		Notebook $notebookName, tabs = {leftMarginPoints, leftMarginPoints + points(3/16), leftMarginPoints + points(3/16) * 2, leftMarginPoints + points(3/16) * 3, leftMarginPoints + points(3/16) * 4}
	endif
	
	GetSelection notebook, $notebookName, 1
	Notebook $notebookName, font = baseCodeFont, text = codeText + "\n"
	Notebook $notebookName, selection = {(V_startParagraph, V_startPos), endOfFile}
	Notebook $notebookName, selection={endOfFile, endOfFile}, textRGB = (0, 0, 0)
	
	insertVerticalPadding(notebookName, 0)
End

// Determines if we're drawing a tagged element (e.g <IgorFencedCode_python>) and finds the end tag
// Since the input to this function is a single line (separated by \n), the ending tag might be
// in a future line. So here we detect the start tag, and then traverse further into the list item
// to find the end tag. The index of the end tag gets returned so that the calling function doesn't
// try to redraw the same lines again.
//
// line			: Text in the line to search. This is a single line of a list item
// fullListItem	: The full text of the list item
// index		: Current index of the list
// context		: Context of the line
static function getPossibleMultilineElement(String& line, String fullListItem, Variable index, struct LineContext& context)
	Variable whichElement
	
	Variable originalIndex = index
	
	String searchTerm
	Variable searchTermLen
	
	String language
	String elementText
	SplitString/E="<IgorFencedCode_(.*?)>([\S\s]*)" line, language, elementText
	if (strlen(elementText))
		whichElement = FencedCodeElement
		searchTerm = "</IgorFencedCode>"
		context.isCodeBlock = 1
	else
		context.isCodeBlock = 0
	endif
	
	if (whichElement == NoElement)
		SplitString/E="<IgorTable>([\S\s]*)" line, elementText
		if (strlen(elementText))
			whichElement = TableElement
			searchTerm = "</IgorTable>"
			context.isTable = 1
		else
			context.isTable = 0
		endif
	endif
	
	if (whichElement == NoElement)
		SplitString/E="<IgorQuote>([\S\s]*)" line, elementText
		if (strlen(elementText))
			whichElement = QuoteElement
			searchTerm = "</IgorQuote>"
			context.isQuote = 1
		else
			context.isQuote = 0
		endif
	endif
	
	if (whichElement == NoElement)
		return originalIndex
	endif
	
	searchTermLen = strlen(searchTerm)
	
	// Search for the end tag on the same line
	Variable found = strsearch(line, searchTerm, 0)
	if (found != -1)
		return index
	endif
	
	Variable nLines = ItemsInList(fullListItem, "\n")
	
	do 
		index++
		if (index >= nLines)
			break
		endif
		
		String nextline = StringFromList(index, fullListItem, "\n")
		found = strsearch(nextline, searchTerm, 0)
		if (found != -1)
			line += "\n" + nextLine[0,found + searchTermLen]
			break
		else 
			line += "\n" + nextLine
		endif
	while (1)
	
	if (found == -1)
		// ERROR! Couldn't find the ending tag
		print "Couldn't find the ending tag of a multi-line tagged element!"
		return originalIndex
	endif
	
	return index
end

// Converts a simple markdown file to an Igor formatted notebook
//
// markdownPath	: Unquoted native path to the markdown file to convert	
// name			: Name of the notebook to create
// fileName		: Name of the help file + extension to save after converting (e.g. 'Whats New In Igor Pro 10.ihf')
// doHighlight	: Set to 1 to syntax highlight code blocks, or 0 to not do any syntax highlighting
Function md2ihf(String markdownPath, String name, String fileName, struct LineContext& context, [Variable appendMode])
		
	// We expect the ParseMarkdown.py script to be in the same directory
	// as this procedure file.
	String thisFilePath = FunctionPath("")
	String scriptFilePath = ParseFilePath(1, thisFilePath, ":", 1, 0)
	scriptFilePath += "ParseMarkdown.py"
	scriptFilePath = ParseFilePath(5, scriptFilePath, "\\", 0, 0)
	scriptFilePath = ReplaceString("\\", scriptFilePath, "/")

	// This needs from other code so that relative paths to images can work
	NewPath/Z/O/Q mdFolderPath, ParseFilePath(1, markdownPath, "\\", 1, 0)
	if (V_flag)
		fprintf -2,"%s\n", "Couldn't create the symbolic path to the markdown folder"  
		return V_flag
	endif
	PathInfo mdFolderPath
	
	// Quote markdownPath
	markdownPath = "\"" + markdownPath + "\""

	Make/T/O/N=(0,2) outputData
	
	PythonFile/Z file = scriptFilePath, args = markdownPath, array = {"output", outputData};
	if (V_flag)
		// Print any error message to stderr
		fprintf -2,"%s\n", GetErrMessage(V_flag, 3)  
		return V_flag
	endif

	// Check that the wave is an expected shape (2 columns only)
	if (WaveDims(outputData) != 2 || DimSize(outputData, 1) != 2)
		// Print any error message to stderr
		fprintf -2,"%s\n", "md2ihf did not receive a text wave from Python of the expected shape." 
		return V_flag
	endif
		
	if (ParamIsDefault(appendMode))
		String windows = winlist(name,";","WIN:80")
		if (!strlen(windows))
			Variable whichWin
			
			// The notebook has a parent, 
			if (strsearch(name, "#", 0) != -1)
				String parent = StringFromList(0, name, "#")
				String child = StringFromList(1, name, "#")
				
				String childList = ChildWindowList(parent)
				
				if (WhichListItem(child, childList) == -1 || WinType(name) != 5)
					// Couldn't find the notebook, make one of just the child name
					NewNotebook/N=$name/K=1/F=1/W=(16,40,600,574) as child
				endif
			else
				NewNotebook/N=$name/K=1/F=1/W=(16,40,600,574) as name
			endif
		endif
		
		// Clear the notebook before doing anything else
		Notebook $name, selection ={startOfFile, endOfFile} , setData = ""
	
	endif
		
	
	Notebook $name, font = baseFont, defaultTab = points(0.25)

	if (ParamIsDefault(appendMode)) 
		setupRulers(name)
	endif
	
	Notebook $name, ruler = Paragraph

	
	Variable/G root:nextLineIsOperation/N= nextLineIsOperation = 0
	Variable/G root:nextLineIsIndentedSubtopic/N=nextLineIsIndentedSubtopic = 0
	Variable/G root:insideOperation/N= insideOperation = 0
	Variable/G root:nextLineIsMethod/N= nextLineIsMethod = 0
	Variable/G root:nextLineIsOverload/N= nextLineIsOverload = 0
	Variable/G root:nextLineIsIgorOverload/N= nextLineIsIgorOverload = 0
	Variable/G root:insideMethod/N= insideMethod = 0
	Variable/G root:nextLineIsIgorOperator/N= nextLineIsIgorOperator = 0
	
	Variable justFinishedList = 0
	
	String codeText, language
	Variable i, j, k
	Variable nLines = DimSize(outputData, 0)
	
	for (i = 0; i < nLines; i++)
		clearContext(context)
				
		String line = outputData[i][0]
		String type = outputData[i][1]
		
		strswitch (type)
			case "H1":
			case "H2":
			case "H3":
			case "H4":
				drawHeader(name, line, type, context)

				if (i < nLines - 1)
					if (cmpstr(outputData[i+1][1], "BlankLine"))
						Notebook $name, text = "\n"
					endif
				endif
				
				nextLineIsOperation = 0
				nextLineIsMethod = 0
				nextLineIsOverload = 0
				nextLineIsIgorOverload = 0
				nextLineIsIgorOperator = 0
				nextLineIsIndentedSubtopic = 0
				
				break
			case "Paragraph":
				drawParagraphElements(name, line, 0, context)			
				break
			case "FencedIgorCode":
			case "FencedCode":
				SplitString/E="<IgorFencedCode_(.*?)>([\S\s]*)</IgorFencedCode>" line, language, codeText
				drawFencedCode(name, codeText, language, context) 
				break
			case "FencedPythonCode":
				SplitString/E="<IgorFencedCode_(.*?)>([\S\s]*)</IgorFencedCode>" line, language, codeText
				drawFencedCode(name, codeText, language, context)
				break
			case "CodeBlock":
				// Set as an indented block, not treated as actual code
				drawParagraphElements(name, line, 1, context)
				break
			case "UnorderedList":
			case "OrderedList":
			
				ensureEmptyLine(name)
				
				Notebook $name, ruler = List
				Variable nListItems = ItemsInList(line, "\n")
				
				context.isList = 1
				
				for (j = 0; j < nListItems; ++j)
					String item = TrimString(StringFromList(j, line, "\n"))
					
					if (firstCharIsNumber(item) || firstCharIsBullet(item))
						context.listLength += 1
					endif
				endfor	
			
				Notebook $name ruler = List
						
				for (j = 0; j < nListItems; ++j)

					String listHeader = StringFromList(j, line, "\n")
					
					if (!strlen(listHeader))
						continue
					endif

					String trimmed = TrimString(listHeader)
					
					// If a multi-line tagged element (like a code block, table, or quote) is found,
					// j will increment automatically so it is at the end of the element
					j = getPossibleMultilineElement(trimmed, line, j, context)
					
					if (firstCharIsBullet(trimmed))
						context.listDepth = nLeadingTabs(listHeader)
						context.isListParagraph = 0
						setListMargin(context, 1)							
					elseif (firstCharIsNumber(trimmed))
						context.listDepth = nLeadingTabs(listHeader)
						context.isListParagraph = 0
						setListMargin(context, 2)
					else
						context.isListParagraph = 1
					endif
											
					// Move the ruler over if necessary
					Notebook $name margins = {points(context.listIndent[context.listDepth]), points(context.listLeft[context.listDepth]), points(6.5)}
					
					drawParagraphElements(name, trimmed, 0, context)
				
					if (j < nListItems - 1)
						Notebook $name, text = "\n"
					endif			
				endfor
				
				Notebook $name, text = "\n"
				justFinishedList = 1
				break
			case "Table":
				String tableText
				SplitString/E="<IgorTable>([\S\s]*)</IgorTable>" line, tableText
				drawTableElements(name, tableText, context)
				break
			case "HTMLBLock":
			
				if (insideOperation)
					Notebook $name, ruler = IndentedParagraph
				else
					Notebook $name, ruler = Paragraph
				endif
				
				drawHTMLBlockElement(name, line, context)
				break
			case "Quote":
				String quoteText
				SplitString/E="<IgorQuote>([\S\s]*)</IgorQuote>" line, quoteText
				drawQuoteElement(name, quoteText, context)
				break
			case "BlankLine":
				// If a list was just completed, we don't want a full newline because it
				// produces a bit too much space, instead we insert vertical padding
				if (justFinishedList)
					insertVerticalPadding(name, 1)
					 
					if (insideOperation)
						Notebook $name ruler = IndentedParagraph
					else
						Notebook $name ruler = Paragraph
					endif
					
					justFinishedList = 0
				else
					Notebook $name, text = "\n"
				endif
				
				break
			default:
				if (insideOperation)
					Notebook $name ruler = IndentedParagraph
				else
					Notebook $name ruler = Paragraph
				endif
				break							
		endswitch
		
	endfor
	
	// Navigate to the top of the file
	if (ParamIsDefault(appendMode))
		Notebook $name selection =  {startOfFile, startOfFile}, findText = {"", 1}
	endif
	
	if (strlen(fileName))
		// Make sure .ihf is the ending
		fileName = ReplaceString(".ihf", fileName, "") + ".ihf"
		SaveNotebook/O/P=mdFolderPath/S=2 $name as fileName
	endif
	
	return 0
End


// Builds Igor References.ihf from the file at pathToBuildFile.
// The build file is a .yml file defining the help topics and what order they should
// appear in. Note that Topic names (not subtopics) are the top level items in the build
// file, and these define the actual text of the Topic. There is no text in any of the
// markdown files that define the Topic name. 
function BuildIgorReference(String pathToBuildFile, String pathToSaveFolder)
	
	NewPath/Z/O/Q IgorRefSaveFolder, pathToSaveFolder
	if (V_flag)
		print "Invalid save folder for Igor Reference: " + pathToSaveFolder
		fprintf -2, "Invalid save folder for Igor Reference: " + pathToSaveFolder
	endif
	
	// In case the file wasn't closed before due to debugging
	Close/A
	
	String baseFolder = ParseFilePath(1, pathToBuildFile, "\\", 1, 0)
	
	Variable ref
	Open/R/Z ref as pathToBuildFile
	
	String notebookName = "IgorReference"
	KillWindow/Z $notebookName
		
	NewNotebook/N=$notebookName/F=1/V=1 // write-protect
	Notebook $notebookName, changeableByCommandOnly = 1
	
//	Execute "SetIgorOption notebookNoUpdate = 1"
	
	Variable timer = StartMSTimer
	
	struct LineContext context
	String line = ""
	
	setupRulers(notebookName)
	
	do			
		FReadLine ref, line
		if (!strlen(line))
			break
		endif
		
		String trimmedLine = TrimString(line)
		if (!strlen(trimmedLine) || !cmpstr(trimmedLine[0], "#"))
			// Comment or empty line
			continue
		endif
		
		if (CmpStr(line[0],"\t") && CmpStr(line[0]," "))
			
			// Topic
			line = RemoveEnding(line, ":\r")
			
			drawHeader(notebookName, line, "H1", context) 
			
			Notebook $notebookName, text = "\n"

		else
			// Subtopic file
			String mdFile = ""
			SplitString/E="\s*-\s(.*?)(?=[#\r\n].*)" line, mdFile
			
			if (!strlen(mdFile))
				continue
			endif
			
			mdFile = baseFolder + TrimString(mdFile) + ".ihf.md"

			Variable err = md2ihf(mdFile, notebookName, "", context, appendMode = 1)
			Notebook $notebookName, text = "\n"

		endif
		
	while(1)
	
//	Execute "SetIgorOption notebookNoUpdate = 0"
	
	Notebook $notebookName, selection = {startOfFile, startOfFile}, findText={"", 1}
	
	// Save notebook once at the end instead of after each append
	SaveNotebook/O/P=IgorRefSaveFolder/S=2 $notebookName as "Igor Reference.ihf"
	
	Close ref
	
	print StopMSTimer(timer) / (1e6), "s"
	
	return err
end