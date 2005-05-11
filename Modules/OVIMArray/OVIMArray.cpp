#define OV_DEBUG
#include"OVIMArray.h"
#include<OpenVanilla/OVLibrary.h>
#include<OpenVanilla/OVUtility.h>

using namespace std;

void OVIMArrayContext::updateDisplay(OVBuffer* buf){
    buf->clear();
    if (keyseq.length()){   
        string str;
        keyseq.compose(str);
        buf->append(str.c_str());
    }
    buf->update();
}

int OVIMArrayContext::updateCandidate(OVCIN *tab,OVBuffer *buf, OVCandidate *candibar){
    tab->getWordVectorByChar(keyseq.getSeq(), candidateStringVector);
    string currentSelKey = tab->getSelKey();
    if( candidateStringVector.size() == 0 && candi.onDuty() )
        clearCandidate(candibar);
    else
        candi.prepare(&candidateStringVector,
                          const_cast<char*>(currentSelKey.c_str()), candibar);
    return 1;
}

int OVIMArrayContext::WaitKey1(OVKeyCode* key, OVBuffer* buf, 
                               OVCandidate* candibar, OVService* srv){
    updateCandidate(short_tab, buf, candibar);
    if( key->code() == 't' )
        buf->clear()->append((char*)"的")->update();
    if( isprint(key->code()) && keyseq.valid(key->code()) )
        changeState(STATE_WAIT_KEY2);
    return 1;    
}

int OVIMArrayContext::WaitKey2(OVKeyCode* key, OVBuffer* buf, 
                               OVCandidate* candibar, OVService* srv){
    updateCandidate(short_tab, buf, candibar);
    if( key->code() == ovkBackspace || key->code() == ovkDelete)
        changeState(STATE_WAIT_KEY1);
    else
        changeState(STATE_WAIT_KEY3);
    return 1;    
}

int OVIMArrayContext::WaitKey3(OVKeyCode* key, OVBuffer* buf, 
                               OVCandidate* candibar, OVService* srv){
    updateCandidate(short_tab, buf, candibar);
    return 1;    
}


int OVIMArrayContext::WaitCandidate(OVKeyCode* key, OVBuffer* buf, 
                                    OVCandidate* candibar, OVService* srv){
    // enter == first candidate
    // space (when candidate list has only one page) == first candidate
    char c=key->code();
    if (c == ovkReturn || (candi.onePage() && c==ovkSpace)) 
        c=candi.getSelKey()[0];

    string output;
    if (candi.select(c, output)) {
        buf->clear()->append(output.c_str())->send();
        clearAll(buf, candibar);
        return 1;
    }
    return 0;
}

void OVIMArrayContext::clearAll(OVBuffer* buf, OVCandidate* candi_bar){
    clearCandidate(candi_bar);
    buf->clear()->update();
    keyseq.clear();
}

void OVIMArrayContext::clearCandidate(OVCandidate *candi_bar){           
    candi.cancel();
    candi_bar->hide()->clear();
}   

int OVIMArrayContext::selectCandidate(int num, string& out){
   char c=candi.getSelKey()[num];
   return candi.select(c, out);
}

int OVIMArrayContext::keyEvent(OVKeyCode* key, OVBuffer* buf, 
                               OVCandidate* candi_bar, OVService* srv)
{
    const char keycode = key->code();
    const bool validkey = keyseq.valid(keycode);

    if(keycode==ovkEsc){
        clearAll(buf, candi_bar);
        changeState(STATE_WAIT_KEY1);
        return 1;
    }

    if( state == STATE_WAIT_CANDIDATE )
        return WaitCandidate(key, buf, candi_bar, srv);
    if( candi.onDuty() && keycode >= '0' && keycode <= '9' ){
        string c;
        if( candi.select(keycode, c) ){
            if( c != "□"  ){
                buf->clear()->append(c.c_str())->send();
                clearAll(buf, candi_bar);
                changeState(STATE_WAIT_KEY1);
            }
            else
                srv->beep();
        }
    }
    if (keyseq.length() && keycode == ovkSpace){
        main_tab->getWordVectorByChar(keyseq.getSeq(), candidateStringVector);
        if(candidateStringVector.size() == 1){
            string c;
            if(selectCandidate(0, c)){
                buf->clear()->append(c.c_str())->send();
                clearAll(buf, candi_bar);
            }
        }
        else{
            updateCandidate(main_tab, buf, candi_bar);
            changeState(STATE_WAIT_CANDIDATE);
        }
        return 1;
    }
    if( isprint(keycode) && validkey ){
        keyseq.add(keycode);
        updateDisplay(buf);
    }
    else if (key->code() == ovkDelete || key->code() == ovkBackspace){   
        keyseq.remove();
        updateDisplay(buf);
        changeBackState(state);
    }
    switch(state){
        case STATE_WAIT_KEY1:
            WaitKey1(key, buf, candi_bar, srv);
            break;
        case STATE_WAIT_KEY2:
            WaitKey2(key, buf, candi_bar, srv);
            break;
        case STATE_WAIT_KEY3:
            WaitKey3(key, buf, candi_bar, srv);
            break;
        default:
            break;
    }
    return 1;
}

int OVIMArray::initialize(OVDictionary *, OVService*, const char *mp){
    main_tab = new OVCIN("/tmp/array30.cin"); // FIXME: correct the path
    short_tab = new OVCIN("/tmp/ArrayShortCode.cin");
    return 1;
}

OV_SINGLE_MODULE_WRAPPER(OVIMArray);
