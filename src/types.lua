--- @class SharedDictionary 
--- @field incr fun(self: SharedDictionary, key: string, n: number): number
--- @field set fun(self: SharedDictionary, key: string, value: any)
--- @field get fun(self: SharedDictionary, key: string): string | number
--- @field get_keys fun(self: SharedDictionary, n?: number): string[]
--- @field capacity fun(self: SharedDictionary): number
--- @field free_space fun(self: SharedDictionary): number


--- @alias HandlerFunction fun(request: Request): Response