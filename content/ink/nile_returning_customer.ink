VAR last_service = "none"
=== start ===
{
- last_service == "good":
    Mahmoud: I remember that tea last time. You got the timing right. # beat:memory_good # point:memory_reply
- last_service == "okay":
    Mahmoud: That cup last time did the job. Another evening, another tea. # beat:memory_okay # point:memory_reply
- last_service == "rough":
    Mahmoud: That tea last time was rather rough. Go easier on it today? # beat:memory_rough # point:memory_reply
- last_service == "settled":
    Mahmoud: I paid for my order last time. Good to see you here again. # beat:memory_settled # point:memory_reply
- last_service == "abandoned":
    Mahmoud: I had to leave before my order last time. Can we try again? # beat:memory_abandoned # point:memory_reply
}
* [Do you know where I can buy fresh tea leaves?]
    Mahmoud: Hoda sends a runner here: thirty grams, 450 for leaves and 100 delivery. # beat:memory_supplier
* [I'll leave you to your evening.]
    Mahmoud: Of course. We can just have our tea. # beat:memory_leave
-
Mahmoud: Take your time. I'll be here a little while. # beat:memory_end
-> END
