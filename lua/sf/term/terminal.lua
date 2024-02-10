local api = vim.api
local cmd = api.nvim_command

local Term = {}
local H = {}

function Term:new()
  return setmetatable({
    win = nil,
    buf = nil,
    is_running = false,
    config = H.defaults,
  }, { __index = self })
end

function Term:setup(cfg)
  if not cfg then
    return vim.notify('SFTerm: setup() is optional. Please remove it!', vim.log.levels.WARN)
  end

  self.config = vim.tbl_deep_extend('force', self.config, cfg)

  return self
end

function Term:store(win, buf)
  self.win = win
  self.buf = buf

  return self
end

function Term:run(cmd)
  if self.is_running then
    return vim.notify('Wait the current task to finish.', vim.log.levels.WARN)
  end

  local running_buf = api.nvim_create_buf(false, true)
  vim.bo[running_buf].filetype = self.config.ft

  local running_win = nil

  if H.is_win_valid(self.win) then
    api.nvim_win_set_buf(self.win, running_buf)
    running_win = self.win
  else
    running_win = self:create_and_open_win(running_buf)
  end

  self:store(running_win, running_buf):run_after_setup(cmd)

  return self
end

function Term:run_after_setup(cmd)
  self:remember_cursor()
  api.nvim_set_current_win(self.win)
  local RED = '\033[0;31m'
  local NC = '\033[0m'
  -- local cmd = 'echo -e "plain \\e[0;31mRED MESSAGE \\e[0m reset"'
  local cmd = string.format('echo -e "\\e[0;35m %s reset";%s', cmd, cmd)

  vim.fn.termopen(cmd, {
    clear_env = self.config.clear_env,
    env = self.config.env,
    on_exit = function()
      self.is_running = false
      self:close() -- hack way to scroll to end
      self:open()
    end,
  })

  self.is_running = true

  vim.bo[self.buf].filetype = self.config.ft -- force filetype

  self:restore_cursor()

  return self
end

function Term:toggle()
  if H.is_win_valid(self.win) then
    self:close()
  else
    self:open()
  end

  return self
end

function Term:open()
  if H.is_win_valid(self.win) then
    return
  end

  if not H.is_buf_valid(self.buf) then
    return vim.notify('No running task to display.', vim.log.levels.WARN)
  end

  local win = self:create_and_open_win(self.buf)
  self:remember_cursor()

  api.nvim_set_current_win(win)
  self:scroll_to_end():restore_cursor()

  self:store(win, self.buf)

  return self
end

function Term:close()
  if not H.is_win_valid(self.win) then
    return self
  end

  api.nvim_win_close(self.win, false)

  return self
end

function Term:create_and_open_win(buf)
  local cfg = self.config

  local dim = H.get_dimension(cfg.dimensions)

  local win = api.nvim_open_win(buf, false, {
    border = cfg.border,
    relative = 'editor',
    style = 'minimal',
    title = 'SFTerm',
    title_pos = 'center',
    width = dim.width,
    height = dim.height,
    col = dim.col,
    row = dim.row,
  })

  api.nvim_win_set_option(win, 'winhl', ('Normal:%s'):format(cfg.hl))
  api.nvim_win_set_option(win, 'winblend', cfg.blend)

  return win
end

function Term:remember_cursor()
  self.last_win = api.nvim_get_current_win()
  self.prev_win = vim.fn.winnr('#')
  self.last_pos = api.nvim_win_get_cursor(self.last_win)

  return self
end

function Term:restore_cursor()
  if self.last_win and self.last_pos ~= nil then
    if self.prev_win > 0 then
      cmd(('silent! %s wincmd w'):format(self.prev_win))
    end

    if H.is_win_valid(self.last_win) then
      api.nvim_set_current_win(self.last_win)
      api.nvim_win_set_cursor(self.last_win, self.last_pos)
    end

    self.last_win = nil
    self.prev_win = nil
    self.last_pos = nil
  end

  return self
end

function Term:scroll_to_end()
  cmd('$')
  return self
end

-- helper -------------------

H.defaults = {
  ft = 'SFTerm',
  border = 'single',
  auto_close = false,
  hl = 'Normal',
  blend = 10,
  clear_env = false,
  dimensions = {
    height = 0.4,
    width = 0.8,
    x = 0.5,
    y = 0.9,
  },
}

function H.is_win_valid(win)
  return win and vim.api.nvim_win_is_valid(win)
end

function H.is_buf_valid(buf)
  return buf and vim.api.nvim_buf_is_loaded(buf)
end

function H.get_dimension(opts)
  -- get lines and columns
  local cl = vim.o.columns
  local ln = vim.o.lines

  -- calculate our floating window size
  local width = math.ceil(cl * opts.width)
  local height = math.ceil(ln * opts.height - 4)

  -- and its starting position
  local col = math.ceil((cl - width) * opts.x)
  local row = math.ceil((ln - height) * opts.y - 1)

  return {
    width = width,
    height = height,
    col = col,
    row = row,
  }
end

return Term
