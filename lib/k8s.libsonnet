{
  // sanitize k8s resource name
  sanitizeName(name): 
    local dashCode = std.codepoint('-');
    local m = std.foldl(
        function(last, char) 
            local code = std.codepoint(char);
            last {
                legal: (code >= 48 && code <= 57) || (code >=65 && code <=90) || (code >= 97 && code <= 122),
                codes+: 
                    if (code >= 65) && (code <= 90) then // for uppercase letter, to lowercase
                        if last.legal then [code+32] else [dashCode, code+32]
                    else 
                        if (code >= 97 && code <= 122) || (code >= 48 && code <= 57) then // for lowercase letter or digit
                            if last.legal then [code] else [dashCode, code]
                        else [],
            },
        std.stringChars(name), 
        {legal: false, codes: []});
    std.stripChars(std.decodeUTF8(m.codes), '-')
}