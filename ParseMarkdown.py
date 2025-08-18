import sys
import marko as md
from marko import Markdown
from marko.block import Heading, Paragraph, BlankLine, List, ListItem, FencedCode, CodeBlock, HTMLBlock, Quote
from marko.inline import LineBreak, RawText, Link, AutoLink, Image, CodeSpan, Emphasis, StrongEmphasis, InlineHTML, Literal

from marko.ext.gfm import GFM
from marko.ext.gfm.elements import Table, TableCell, TableRow, Url, Alert

import igorpro

depth: int = -1

class IgorMarkdown():
    def __init__(self):
        self.data : list = []

class ParsedElement():
    def __init__(self, text: str, type: int):
        self.text = text
        self.type = type

def convert_text(text : str) -> IgorMarkdown:

    md = Markdown(extensions=['gfm'])
    doc = md.parse(text)

    output = IgorMarkdown()
    for element in doc.children:
        parsedElement = parseElement(element)

        # Skip blank lines
        if (len(parsedElement.text)):
            output.data.append((parsedElement.text, parsedElement.type))

    return output

def convert_doc(path : str) -> IgorMarkdown:
    # Open the file and run it through the markdown parser
    # This produces an AST-like object that we can walk through
    f = open(path, encoding="utf8")
    text = f.read()

    md = Markdown(extensions=['gfm'])
    doc = md.parse(text)

    output = IgorMarkdown()
    for element in doc.children:
        parsedElement = parseElement(element)

        # Skip blank lines
        if (len(parsedElement.text)):
            output.data.append((parsedElement.text, parsedElement.type))

    f.close()

    return output

# Parse an arbitrary element
def parseElement(element, parent: md.block = None) -> ParsedElement:
    elementText: str = ''
    type = ''

    if isinstance(element, md.block.Heading):
        elementText = parseHeading(element)
        type = f'H{element.level}'
    elif isinstance(element, md.block.BlankLine):
        elementText = parseBlankLine(element)
        type = 'BlankLine'
    elif isinstance(element, md.block.Paragraph):
        elementText = parseParagraph(element, parent)

        if isinstance(parent, List):
            type = 'ListItem'
        else:
            type = 'Paragraph'       

    elif isinstance(element, LineBreak):
        elementText = parseLineBreak(element)
        type = 'LineBreak'
    elif isinstance(element, RawText):
        elementText = parseRawText(element)
        type = 'RawText'
    elif isinstance(element, List):
        elementText = parseList(element)
        if element.ordered:
            type = 'OrderedList'
        else:
            type = 'UnorderedList'
    elif isinstance(element, Emphasis):
        elementText = parseEmphasis(element)
        type = 'Italic'
    elif isinstance(element, StrongEmphasis):
        elementText = parseStrongEmphasis(element)

        if isinstance(parent, ListItem):
            type = 'ListItem'
        else:
            type = 'Bold'    
    elif isinstance(element, ListItem):
        elementText = parseListItem(element)
        type = 'ListItem'
    elif isinstance(element, Link):
        elementText = parseLink(element)
        type = 'Link'
    elif isinstance(element, Url):
        # Url is an autolink, so it must come before our AutoLink handling
        elementText = parseUrl(element)
        type = 'Paragraph'
    elif isinstance(element, AutoLink):
        elementText = parseAutoLink(element)
        type = 'HTMLLink'
    elif isinstance(element, HTMLBlock):
        elementText = parseHTMLBlock(element)
        type = 'HTMLBlock'
    elif isinstance(element, InlineHTML):
        elementText = parseInlineHTML(element)
        type = 'InlineHTML'
    elif isinstance(element, Image):
        elementText = parseImage(element)
        type = 'Image'
    elif isinstance(element, FencedCode):
        elementText = parseFencedCode(element)
        if element.lang == "igor":
            type = 'FencedIgorCode'
        elif element.lang == "python":
            type = 'FencedPythonCode'
        else:
            type = 'FencedCode'
    elif isinstance(element, CodeBlock):
        elementText = parseCodeBlock(element)
        type = 'CodeBlock'
    elif isinstance(element, CodeSpan):
        elementText = parseCodeSpan(element)
        type = 'CodeSpan'
    elif isinstance(element, Table):
        elementText = parseTable(element)
        type = 'Table'
    elif isinstance(element, TableRow):
        elementText = parseTableRow(element)
        type = 'TableRow'
    elif isinstance(element, TableCell):
        elementText = parseTableCell(element)
        type = 'TableCell'   
    elif isinstance(element, Literal):
        elementText = parseLiteral(element)
        type = 'Literal'
    elif isinstance(element, Alert):
        elementText = parseAlert(element)
        type = 'Quote'
    elif isinstance(element, Quote):
        elementText = parseQuote(element)
        type = 'Quote'
    return ParsedElement(elementText, type)

# Headings
def parseHeading(heading : Heading) -> str:
    level = heading.level
    headerText = ''

    for element in heading.children:
        headerText += parseElement(element).text
    return headerText

# Paragraphs
def parseParagraph(paragraph : Paragraph, parent: md.block = None) -> str:
    paragraphText = ''
    for line in paragraph.children:
        paragraphText += parseElement(line, parent).text
    return paragraphText

# Blank line
def parseBlankLine(blankline : BlankLine):
    return '\n'

# Line breaks
def parseLineBreak(linebreak : LineBreak) -> str:
    if linebreak.soft is True:
        return ' '
    else:
        return '<br>'

# Raw text
def parseRawText(rawtext : RawText) -> str:
    return rawtext.children

# Emphasis (italic)
def parseEmphasis(emphasis : Emphasis) -> str:
    italicText = '<IgorItalic>'
    for line in emphasis.children:
        italicText += parseElement(line).text
    italicText += '</IgorItalic>'
    return italicText

# Strong emphasis (bold)
def parseStrongEmphasis(strongEmphasis : StrongEmphasis) -> str:
    boldText = '<IgorBold>'
    for line in strongEmphasis.children:
        boldText += parseElement(line).text
    boldText += '</IgorBold>'
    return boldText

# List
def parseList(theList : List):
    listText = ''
    i = theList.start
    
    global depth
    depth += 1
    indentation = str('\t') * depth

    for listItem in theList.children:
        elementText = parseElement(listItem).text

        #remove leading tabs from elementText
        elementText = elementText.strip('\t')

        if (theList.ordered):         
            listText += indentation + f"{i}.\t" + elementText
        else:
            listText += indentation + '•\t' + elementText

        i += 1
    
    depth -= 1
    return listText

# List item
def parseListItem(listItem : ListItem):
    itemText = ''

    for element in listItem.children:
        parsed = parseElement(element, listItem)        
        elementText = parsed.text

        if elementText == '\n':
            # Prevents double new lines
            continue
      
        itemText += elementText + '\n'
        
    return itemText

# Link
def parseLink(theLink : Link):
    linkText = '<IgorLink>['
    for element in theLink.children:
        parsedElement = parseElement(element)
        linkText += parsedElement.text

    linkText += f"]({theLink.dest})</IgorLink>"   
    return linkText

def parseAutoLink(theAutoLink : AutoLink):
    return f'<IgorHTML><{theAutoLink.dest}></IgorHTML>'

def parseHTMLBlock(theHTMLBlock : HTMLBlock):
    return theHTMLBlock.body

def parseInlineHTML(theInlineHTML : InlineHTML):
    if theInlineHTML.children == '<blockquote>':
        return '<IgorQuote>'
    elif theInlineHTML.children == '</blockquote>':
        return '</IgorQuote>'
    
    return theInlineHTML.children

# Image
def parseImage(theImage : Image):
    imageText = '<IgorImage>['
    for element in theImage.children:
        imageText += parseElement(element).text
    imageText += "](" + theImage.dest + ")</IgorImage>"
    return imageText

# Fenced code
# '''language 
# code
# '''
def parseFencedCode(fencedCode : FencedCode):
    if len(fencedCode.lang) > 0:
        codeText = f'<IgorFencedCode_{fencedCode.lang}>'#f"```{fencedCode.lang}\n"
    else:
        # If no language is specified
        codeText = f'<IgorFencedCode_Other>'#f"```{fencedCode.lang}\n"

    for line in fencedCode.children:
        codeText += parseElement(line).text.removesuffix('\n')
    # codeText += "```"
    codeText += '</IgorFencedCode>'
    return codeText

# Code span ('code')
def parseCodeSpan(codeSpan : CodeSpan):
    return "<IgorCode>" + codeSpan.children + "</IgorCode>"

# Code block, basically just indentation
def parseCodeBlock(codeBlock : CodeBlock):
    blockText = ''
    for line in codeBlock.children:
        blockText += parseElement(line).text

    return blockText

def parseTable(table : Table):
    tableText = '<IgorTable>'
    for row in table.children:
        tableText += parseElement(row).text
    
    tableText += "</IgorTable>"
    return tableText

def parseTableRow(tableRow : TableRow):
    tableRowText = '<TableDiv>'
    for cell in tableRow.children:
        tableRowText += parseElement(cell).text
    
    tableRowText += '\n'
    return tableRowText

def parseTableCell(tableCell : TableCell):
    tableCellText = ''
    for cell in tableCell.children:
        tableCellText += parseElement(cell).text
    
    tableCellText += '<TableDiv>'
    return tableCellText

def parseLiteral(theLiteral : Literal):
    return theLiteral.children

def parseUrl(theUrl : Url):
    urlText = ''
    for element in theUrl.children:
        urlText += parseElement(element).text

    return urlText

def parseAlert(theAlert : Alert):

    if len(theAlert.children) == 0:
        return ''
    
    quoteText = '<IgorQuote>'

    quoteText += f'[!{theAlert.alert_type}] '

    for element in theAlert.children:
        quoteText += parseElement(element).text

    quoteText += '</IgorQuote>'
    return quoteText

def parseQuote(theQuote : Quote):
    quoteText = '<IgorQuote>'

    for element in theQuote.children:
        quoteText += parseElement(element).text

    quoteText += '</IgorQuote>'
    return quoteText

if __name__ == '__main__':
    path = sys.argv[1]
    # path = "C:/src/BuildIgor/tools/md2ihf/testing/stressTest.md"
    output : list = convert_text(igorpro.string(path).value()).data
