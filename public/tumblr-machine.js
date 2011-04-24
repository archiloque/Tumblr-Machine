$(document).ready(function() {
    $("#tagsTable").tablesorter();
    $("#tagsTable tr").click(function(e) {
        var children = $(e.currentTarget).children();
        $('input[name=tagName]').val($(children[0]).html());
        $('input[name=tagValue]').val($(children[1]).html());
        $('input[name=tagFetch]').attr('checked', $(children[2]).html() == 'true');
    });
    }
);
