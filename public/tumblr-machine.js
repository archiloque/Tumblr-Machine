$(document).ready(function() {
    $(".tagsTable").tablesorter();
    $("#tagsTable1 tr").click(function(e) {
        var children = $(e.currentTarget).children();
        $('input[name=tagName]').val($(children[1]).children()[0].text);
        $('input[name=tagValue]').val($(children[2]).html());
        $('input[name=tagFetch]').attr('checked', $(children[3]).text() == 'true');
    });
    $("#tagsTable2 tr").click(function(e) {
        var children = $(e.currentTarget).children();
        $('input[name=tagName]').val($(children[1]).children()[0].text);
        $('input[name=tagValue]').val(0);
        $('input[name=tagFetch]').attr('checked', false);
    });
});

function clean() {
    callAndDisplayResult('/clean');
}

function fetchNextTags() {
    callAndDisplayResult('/fetch_next_tags');
}

function fetch(tag) {
    callAndDisplayResult('/fetch/' + tag);
}

function reblog(id) {
    if (confirm("Are you sure you want to reblog this post ?")) {
        callAndDisplayResult('/reblog/' + id);
    }
}

function reblogNext() {
    if (confirm("Are you sure you want to reblog the next post ?")) {
        callAndDisplayResult('/reblog_next');
    }
}

function callAndDisplayResult(url) {
    $.get(url, function(data) {
        displayMessage(data);
    });
}

function displayMessage(message) {
    var displayResult = function() {
        $('#messages').append('<div id="notice" class="flash">' + message + '</div>');
    };
    if ($('.flash').length == 0) {
        displayResult();
    } else {
        $('.flash').fadeOut(function() {
            $('.flash').remove();
            displayResult();
        });
    }
}
