if Debug and Debug.beginFile then Debug.beginFile("Libraries/StringLib") end

OnInit("StringLib", function()
    STRING_INDEX_NONE = -1
    STRING_INVALID_SEGMENT = ""

    local whitespace = {
        [" "] = true,
        ["\n"] = true,
        ["\r"] = true,
        ["\t"] = true
    }

    local function length(s)
        return StringLength(s or "")
    end

    local function sub(s, left, right)
        return SubString(s or "", left, right)
    end

    local function maybeIgnoreCase(s, caseSensitive)
        if caseSensitive then
            return s or ""
        end
        return StringCase(s or "", true)
    end

    function StringTrimLeft(str)
        if str == nil then
            return nil
        end

        local left = 0
        local right = length(str)

        while left < right and whitespace[sub(str, left, left + 1)] do
            left = left + 1
        end

        return sub(str, left, right)
    end

    function StringTrimRight(str)
        if str == nil then
            return nil
        end

        local right = length(str)

        while right > 0 and whitespace[sub(str, right - 1, right)] do
            right = right - 1
        end

        return sub(str, 0, right)
    end

    function StringTrim(str)
        if str == nil then
            return nil
        end

        local left = 0
        local right = length(str)

        while left < right and whitespace[sub(str, left, left + 1)] do
            left = left + 1
        end

        while right > left and whitespace[sub(str, right - 1, right)] do
            right = right - 1
        end

        return sub(str, left, right)
    end

    function StringIndexOf(source, toFind, caseSensitive)
        source = maybeIgnoreCase(source, caseSensitive)
        toFind = maybeIgnoreCase(toFind, caseSensitive)

        local sourceLength = length(source)
        local findLength = length(toFind)
        local i = 0

        if findLength == 0 then
            return 0
        end

        while i + findLength <= sourceLength do
            if sub(source, i, i + findLength) == toFind then
                return i
            end
            i = i + 1
        end

        return STRING_INDEX_NONE
    end

    function StringIndexOfReverse(source, toFind, caseSensitive)
        source = maybeIgnoreCase(source, caseSensitive)
        toFind = maybeIgnoreCase(toFind, caseSensitive)

        local findLength = length(toFind)
        local i = length(source) - findLength

        if findLength == 0 then
            return length(source)
        end

        while i >= 0 do
            if sub(source, i, i + findLength) == toFind then
                return i
            end
            i = i - 1
        end

        return STRING_INDEX_NONE
    end

    function StringReplace(source, old, new, caseSensitive)
        source = source or ""
        old = old or ""
        new = new or ""

        local sourceLength = length(source)
        local oldLength = length(old)
        if oldLength == 0 then
            return source
        end

        local compare = maybeIgnoreCase(source, caseSensitive)
        local needle = maybeIgnoreCase(old, caseSensitive)
        local result = ""
        local readIndex = 0
        local lastIndex = 0

        while readIndex < sourceLength do
            if sub(compare, readIndex, readIndex + oldLength) == needle then
                result = result .. sub(source, lastIndex, readIndex) .. new
                readIndex = readIndex + oldLength
                lastIndex = readIndex
            else
                readIndex = readIndex + 1
            end
        end

        return result .. sub(source, lastIndex, sourceLength)
    end

    function StringHashCS(s)
        s = s or ""
        local result = ""
        local i = 0
        local len = length(s)

        while i < len do
            local c = sub(s, i, i + 1)
            if c == "\\" then
                result = result .. "\\\\"
            elseif StringCase(c, false) ~= c then
                result = result .. "\\" .. c
            else
                result = result .. c
            end
            i = i + 1
        end

        return StringHash(result)
    end

    function IsStringAscii(s)
        s = s or ""
        local i = 1
        while i <= string.len(s) do
            if string.byte(s, i) > 127 then
                return false
            end
            i = i + 1
        end
        return true
    end

    function StringAsciiAt(s, index)
        if s == nil or index < 0 or index >= string.len(s) then
            return 0
        end
        return string.byte(s, index + 1)
    end

    function IsStringValidUtf8(s)
        if s == nil then
            return false
        end

        local i = 1
        local len = string.len(s)

        while i <= len do
            local b = string.byte(s, i)
            local width = 0

            if b < 0x80 then
                width = 1
            elseif b >= 0xC2 and b <= 0xDF then
                width = 2
            elseif b >= 0xE0 and b <= 0xEF then
                width = 3
            elseif b >= 0xF0 and b <= 0xF4 then
                width = 4
            else
                return false
            end

            if i + width - 1 > len then
                return false
            end

            local j = 1
            while j < width do
                local continuation = string.byte(s, i + j)
                if continuation < 0x80 or continuation > 0xBF then
                    return false
                end
                j = j + 1
            end

            i = i + width
        end

        return true
    end

    function StringLengthUtf8(s)
        if s == nil then
            return 0
        end

        if not IsStringValidUtf8(s) then
            local bjDebugMsg = rawget(_G, "BJDebugMsg")
            if bjDebugMsg then
                bjDebugMsg("StringLengthUtf8 warning: supplied string is invalid!")
            end
            return length(s)
        end

        local i = 1
        local len = string.len(s)
        local actualLength = 0

        while i <= len do
            local b = string.byte(s, i)
            if b < 0x80 then
                i = i + 1
            elseif b < 0xE0 then
                i = i + 2
            elseif b < 0xF0 then
                i = i + 3
            else
                i = i + 4
            end
            actualLength = actualLength + 1
        end

        return actualLength
    end

    StringSegments = {}
    StringSegments.__index = StringSegments

    function StringSegments.create(source, delimiter)
        local this = {
            source = source or "",
            delimiter = delimiter or "",
            position = 0,
            segments = {}
        }

        setmetatable(this, StringSegments)
        this:recalculate()
        return this
    end

    function StringSegments:recalculate()
        self.segments = {}

        local delimiterLength = length(self.delimiter)
        local sourceLength = length(self.source)
        local i = self.position
        local segmentStart = self.position

        if delimiterLength == 0 or sourceLength == 0 then
            return
        end

        while i <= sourceLength do
            if i == sourceLength or sub(self.source, i, i + delimiterLength) == self.delimiter then
                if i - segmentStart > 0 then
                    self.segments[#self.segments + 1] = {
                        value = sub(self.source, segmentStart, i),
                        nextPosition = i
                    }
                end
                i = i + delimiterLength
                segmentStart = i
            else
                i = i + 1
            end
        end
    end

    function StringSegments:countSegments()
        return #self.segments
    end

    function StringSegments:hasMoreSegments()
        return #self.segments > 0
    end

    function StringSegments:nextSegment()
        local segment = self.segments[1]
        if segment == nil then
            return STRING_INVALID_SEGMENT
        end

        table.remove(self.segments, 1)
        self.position = segment.nextPosition

        return segment.value
    end

    function StringSegments:nextSegmentEx(delimiter)
        self.delimiter = delimiter or ""
        self:recalculate()
        return self:nextSegment()
    end
end)

if Debug and Debug.endFile then Debug.endFile() end
