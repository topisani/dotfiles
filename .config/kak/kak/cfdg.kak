filetype-hook cfdg %{
    hook window BufWritePost .* %{
        cfdg-render
    }
}
