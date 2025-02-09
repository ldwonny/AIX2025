#include <stdio.h>
#include <stdlib.h>

#include "box.h"
#include "pthread.h"

#include "additionally.h"

// ======================================================================
// WARNING: For Board testing, the current version only supports Windows 
// ======================================================================
//{{{
//#define FPGA_BOARD_TEST 1

#define MODE_TEST_HELLO	0x01
#define MODE_TEST_ECHO	0x02
#define MODE_STORE_RAM	0x03
#define MODE_LOAD_RAM	0x04
#define MODE_STORE_CFG	0x05
#define MODE_RUN_ENGINE 0x06
#define MODE_PAUSE		0x07

#ifdef FPGA_BOARD_TEST
    #include <windows.h>

    #define MAX_LEN 256
    #define NUM_CONV_LAYER 11
    
    char data_read[100];
    uint32_t base_addr_config[NUM_CONV_LAYER*2];

    void* open_port(const char* port_name);
    void close_port(HANDLE comport_handle);
    void test_hello(void* comport_handle);
    void test_echo(void* comport_handle);
    // Write and Read data
    void write_from_file_to_fpga(void* comport_handle, const char* file_name, uint32_t base_addr, uint32_t words_to_send);
    void read_from_fpga_to_file(void* comport_handle, const char* file_name, uint32_t base_addr, uint32_t words_to_recv); 
    void write_config(void* comport_handle);
    void start_engine(void* comport_handle);
    void verify_result(const char* src_file, const char* dst_file, uint32_t words_to_check);
    void write_image(char* filename, char* out_filename);

#endif
//}}}
// get prediction boxes: yolov2_forward_network.c
void get_region_boxes_cpu(layer l, int w, int h, float thresh, float **probs, box *boxes, int only_objectness, int *map);

typedef struct detection_with_class {
    detection det;
    // The most probable class id: the best class index in this->prob.
    // Is filled temporary when processing results, otherwise not initialized
    int best_class;
} detection_with_class;

// Creates array of detections with prob > thresh and fills best_class for them
detection_with_class* get_actual_detections(detection *dets, int dets_num, float thresh, int* selected_detections_num)
{
    int selected_num = 0;
    detection_with_class* result_arr = calloc(dets_num, sizeof(detection_with_class));
    int i;
    for (i = 0; i < dets_num; ++i) {
        int best_class = -1;
        float best_class_prob = thresh;
        int j;
        for (j = 0; j < dets[i].classes; ++j) {
            if (dets[i].prob[j] > best_class_prob) {
                best_class = j;
                best_class_prob = dets[i].prob[j];
            }
        }
        if (best_class >= 0) {
            result_arr[selected_num].det = dets[i];
            result_arr[selected_num].best_class = best_class;
            ++selected_num;
        }
    }
    if (selected_detections_num)
        *selected_detections_num = selected_num;
    return result_arr;
}

// compare to sort detection** by bbox.x
int compare_by_lefts(const void *a_ptr, const void *b_ptr) {
    const detection_with_class* a = (detection_with_class*)a_ptr;
    const detection_with_class* b = (detection_with_class*)b_ptr;
    const float delta = (a->det.bbox.x - a->det.bbox.w / 2) - (b->det.bbox.x - b->det.bbox.w / 2);
    return delta < 0 ? -1 : delta > 0 ? 1 : 0;
}

// compare to sort detection** by best_class probability
int compare_by_probs(const void *a_ptr, const void *b_ptr) {
    const detection_with_class* a = (detection_with_class*)a_ptr;
    const detection_with_class* b = (detection_with_class*)b_ptr;
    float delta = a->det.prob[a->best_class] - b->det.prob[b->best_class];
    return delta < 0 ? -1 : delta > 0 ? 1 : 0;
}

void draw_detections_v3(image im, detection *dets, int num, float thresh, char **names, image **alphabet, int classes, int ext_output)
{
    int selected_detections_num;
    detection_with_class* selected_detections = get_actual_detections(dets, num, thresh, &selected_detections_num);

    // text output
    qsort(selected_detections, selected_detections_num, sizeof(*selected_detections), compare_by_lefts);
    int i;
    for (i = 0; i < selected_detections_num; ++i) {
        const int best_class = selected_detections[i].best_class;
        printf("%s: %.0f%%", names[best_class], selected_detections[i].det.prob[best_class] * 100);
        if (ext_output)
            printf("\t(left_x: %4.0f   top_y: %4.0f   width: %4.0f   height: %4.0f)\n",
                round((selected_detections[i].det.bbox.x - selected_detections[i].det.bbox.w / 2)*im.w),
                round((selected_detections[i].det.bbox.y - selected_detections[i].det.bbox.h / 2)*im.h),
                round(selected_detections[i].det.bbox.w*im.w), round(selected_detections[i].det.bbox.h*im.h));
        else
            printf("\n");
        int j;
        for (j = 0; j < classes; ++j) {
            if (selected_detections[i].det.prob[j] > thresh && j != best_class) {
                printf("%s: %.0f%%\n", names[j], selected_detections[i].det.prob[j] * 100);
            }
        }
    }

    // image output
    qsort(selected_detections, selected_detections_num, sizeof(*selected_detections), compare_by_probs);
    for (i = 0; i < selected_detections_num; ++i) {
        int width = im.h * .006;
        if (width < 1)
            width = 1;

        /*
        if(0){
        width = pow(prob, 1./2.)*10+1;
        alphabet = 0;
        }
        */

        //printf("%d %s: %.0f%%\n", i, names[selected_detections[i].best_class], prob*100);
        int offset = selected_detections[i].best_class * 123457 % classes;
        float red = get_color(2, offset, classes);
        float green = get_color(1, offset, classes);
        float blue = get_color(0, offset, classes);
        float rgb[3];

        //width = prob*20+2;

        rgb[0] = red;
        rgb[1] = green;
        rgb[2] = blue;
        box b = selected_detections[i].det.bbox;
        //printf("%f %f %f %f\n", b.x, b.y, b.w, b.h);

        int left = (b.x - b.w / 2.)*im.w;
        int right = (b.x + b.w / 2.)*im.w;
        int top = (b.y - b.h / 2.)*im.h;
        int bot = (b.y + b.h / 2.)*im.h;

        if (left < 0) left = 0;
        if (right > im.w - 1) right = im.w - 1;
        if (top < 0) top = 0;
        if (bot > im.h - 1) bot = im.h - 1;

        draw_box_width(im, left, top, right, bot, width, red, green, blue);
    }
    free(selected_detections);
}



// --------------- Detect on the Image ---------------


// Detect on Image: this function uses other functions not from this file
void test_detector_cpu(char **names, char *cfgfile, char *weightfile, char *filename, char* out_filename, float thresh, int quantized, int save_params, int dont_show)
{
    //image **alphabet = load_alphabet();            // image.c
    image **alphabet = NULL;
    network net = parse_network_cfg(cfgfile, 1, quantized);    // parser.c
    if (weightfile) {
        load_weights_upto_cpu(&net, weightfile, net.n);    // parser.c
    }
    //set_batch_network(&net, 1);                    // network.c
    srand(2222222);
    yolov2_fuse_conv_batchnorm(net);
    if (quantized) {
        printf("\n\n Quantization! \n\n");
        do_quantization(net);
        if (save_params) {
            printf("\n Saving quantized model... \n\n");
            save_quantized_model(net);
        }
    }

    clock_t time;
    char buff[256];
    char *input = buff;
    int j;
    float nms = .4;
    while (1) {
        if (filename) {
            strncpy(input, filename, 256);
        }
        else {
            printf("Enter Image Path: ");
            fflush(stdout);
            input = fgets(input, 256, stdin);
            if (!input) return;
            strtok(input, "\n");
        }
        image im = load_image(input, 0, 0, 3);            // image.c
        image sized = resize_image(im, net.w, net.h);    // image.c
        layer l = net.layers[net.n - 1];

        box *boxes = calloc(l.w*l.h*l.n, sizeof(box));
        float **probs = calloc(l.w*l.h*l.n, sizeof(float *));
        for (j = 0; j < l.w*l.h*l.n; ++j) probs[j] = calloc(l.classes, sizeof(float *));

        float *X = sized.data;
        time = clock();
        if (quantized) {
            network_predict_quantized(net, X);    // quantized
            nms = 0.2;
        }
        else {
            network_predict_cpu(net, X);
        }
        printf("%s: Predicted in %f seconds.\n", input, (float)(clock() - time) / CLOCKS_PER_SEC); //sec(clock() - time));

        float hier_thresh = 0.5;
        int ext_output = 1, letterbox = 0, nboxes = 0;
        detection *dets = get_network_boxes(&net, im.w, im.h, thresh, hier_thresh, 0, 1, &nboxes, letterbox);
        if (nms) do_nms_sort(dets, nboxes, l.classes, nms);
        draw_detections_v3(im, dets, nboxes, thresh, names, alphabet, l.classes, ext_output);

        if (out_filename) {
            save_image_png(im, out_filename);    // image.c
            if (!dont_show) {
                show_image(im, out_filename);    // image.c
            }
        }
        else {
            save_image_png(im, "predictions");    // image.c
            if (!dont_show) {
                show_image(im, "predictions");    // image.c
            }
        }

        free_image(im);                    // image.c
        free_image(sized);                // image.c
        free(boxes);
        free_ptrs((void **)probs, l.w*l.h*l.n);    // utils.c
        if (filename) break;
    }
}

// get command line parameters and load objects names
void run_detector(int argc, char **argv)
{
    int dont_show = find_arg(argc, argv, "-dont_show");
    char *prefix = find_char_arg(argc, argv, "-prefix", 0);
    float thresh = find_float_arg(argc, argv, "-thresh", .25);
    float iou_thresh = find_float_arg(argc, argv, "-iou_thresh", .5);    // 0.5 for mAP
    char *out_filename = find_char_arg(argc, argv, "-out_filename", 0);
    int quantized = find_arg(argc, argv, "-quantized");
    int input_calibration = find_int_arg(argc, argv, "-input_calibration", 0);
    int save_params = find_arg(argc, argv, "-save_params");
    if (argc < 4) {
        fprintf(stderr, "usage: %s %s [map/test] [cfg] [weights (optional)]\n", argv[0], argv[1]);
        return;
    }

    int clear = 0;                // find_arg(argc, argv, "-clear");

    char *obj_names = argv[3];    // char *datacfg = argv[3];
    char *cfg = argv[4];
    char *weights = (argc > 5) ? argv[5] : 0;
    char *filename = (argc > 6) ? argv[6] : 0;

    // load object names
    char **names = calloc(10000, sizeof(char *));
    int obj_count = 0;
    FILE* fp;
    char buffer[255];
    fp = fopen(obj_names, "r");
    while (fgets(buffer, 255, (FILE*)fp)) {
        names[obj_count] = calloc(strlen(buffer)+1, sizeof(char));
        strcpy(names[obj_count], buffer);
        names[obj_count][strlen(buffer) - 1] = '\0'; //remove newline
        ++obj_count;
    }
    fclose(fp);
    int classes = obj_count;

    if (0 == strcmp(argv[2], "test")) test_detector_cpu(names, cfg, weights, filename, out_filename, thresh, quantized, save_params, dont_show);
    else if (0 == strcmp(argv[2], "map")) validate_detector_map(obj_names, cfg, weights, thresh, quantized, save_params, iou_thresh);

    int i;
    for (i = 0; i < obj_count; ++i) free(names[i]);
    free(names);
}


int main(int argc, char **argv)
{
#ifdef FPGA_BOARD_TEST
//{{{   
    // 1. Open the COM/UART port and test the basic communication
    // FIXME: Change the port number
    HANDLE comport_handle = open_port("COM4");
    test_hello(comport_handle);
    test_echo(comport_handle);

    // 2-1. Calculate base addresses and write the model configurations
    network net = parse_network_cfg("C:/skeleton/bin/aix2024.cfg", 1, 0);    // parser.c
    int layer_idx = 0;

    base_addr_config[layer_idx] = 4096;
    layer_idx++;
    for (int j = 0; j < net.n; ++j) {
        layer* l = &net.layers[j];
        if (l->type == CONVOLUTIONAL) {
            uint32_t in_fmap_size = l->h * l->w * max(l->c, 4);
            uint32_t weight_size = l->size * l->size * l->c * l->n;
            base_addr_config[layer_idx++] = base_addr_config[layer_idx - 1] + in_fmap_size;
            base_addr_config[layer_idx++] = base_addr_config[layer_idx - 1] + weight_size;
            fprintf(stderr, "[ADDR  ] Base address conv%02d: (ifmap: %08d)  - (weight: %08d) - (ofmap: %08d)\n", j,
                base_addr_config[layer_idx - 3], base_addr_config[layer_idx - 2], base_addr_config[layer_idx - 1]);
        }
    }

    write_config(comport_handle);
 
    // 2-2. Write an input image from Host to FPGA (DRAM)
    write_from_file_to_fpga(comport_handle, "C:/skeleton/bin/log_feamap/CONV00_input_32b.hex", base_addr_config[0], 256 * 256);  // Input image
 
    // 2-3. Write weights to DRAM on FPGA
    // Note: Weights are in a 32-bit format now. We can speed up four times with 8-bit weights. 
    write_from_file_to_fpga(comport_handle, "C:/skeleton/bin/log_param/CONV00_param_weight.hex", base_addr_config[1], 432);     // Only CONV00 now
    //write_from_file_to_fpga(comport_handle, "C:/skeleton/bin/log_param/CONV10_param_weight.hex", base_address_weight, 1179648);    
 
    // 3. Start the CNN accelerator engine    
    start_engine(comport_handle);   // Do nothing now. 
 
    // 4. Read results from FPGA (DRAM) to Host
    read_from_fpga_to_file(comport_handle, "C:/skeleton/bin/log_result_fpga/CONV00_input_32b.hex", base_addr_config[0], 256 * 256);
    read_from_fpga_to_file(comport_handle, "C:/skeleton/bin/log_result_fpga/CONV00_param_weight.hex", base_addr_config[1], 432);
 
    // 5-1. Verify
    verify_result("C:/skeleton/bin/log_feamap/CONV00_input_32b.hex",   // Input (Src)
        "C:/skeleton/bin/log_result_fpga/CONV00_input_32b.hex",        // Output (Dst)
        256 * 256);                                                    // Number of compared data
 
    verify_result("C:/skeleton/bin/log_param/CONV00_param_weight.hex", // Input (Src)
        "C:/skeleton/bin/log_result_fpga/CONV00_param_weight.hex",     // Output (Dst)
        432);                                                          // Number of compared data
    
    // 5-2. Display
    write_image("C:/skeleton/bin/test01.jpg", "C:/skeleton/bin/log_result_fpga/test01-det-quantized.png");

//}}}
#else

//#ifdef _DEBUG
//    _CrtSetDbgFlag(_CRTDBG_ALLOC_MEM_DF | _CRTDBG_LEAK_CHECK_DF);
//#endif
    int i;
    for (i = 0; i < argc; ++i) {
        if (!argv[i]) continue;
        strip(argv[i]);
    }

    if (argc < 2) {
        fprintf(stderr, "usage: %s <function>\n", argv[0]);
        return 0;
    }
    gpu_index = find_int_arg(argc, argv, "-i", 0);  //  gpu_index = 0;

#ifndef GPU
    gpu_index = -1;
#endif
    run_detector(argc, argv);
#endif 
    return 0;
}

#ifdef FPGA_BOARD_TEST

    void* open_port(const char* port_name) {

        HANDLE comport_handle = CreateFileA(port_name, GENERIC_READ | GENERIC_WRITE, 0, 0, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0);

        if (comport_handle == INVALID_HANDLE_VALUE) {
            fprintf(stderr, "[FAILED] CreateFileA\n");
        }

        DCB serial_params = { 0 };
        serial_params.DCBlength = sizeof(serial_params);

        if (GetCommState(comport_handle, &serial_params) == FALSE) {
            fprintf(stderr, "[FAILED] GetCommState\n");
        }


        serial_params.BaudRate = 230400;   
        serial_params.ByteSize = 8;
        serial_params.StopBits = ONESTOPBIT;
        serial_params.Parity = NOPARITY;

        if (SetCommState(comport_handle, &serial_params) == FALSE) {
            fprintf(stderr, "[FAILED] SetCommState\n");
        }

        //set timeouts
        COMMTIMEOUTS timeout = { 0 };
        SetCommTimeouts(comport_handle, &timeout);

        return comport_handle;
    }

    void close_port(HANDLE comport_handle) {
        CloseHandle(comport_handle);
        return;
    }

    void test_hello(void* comport_handle) {
        DWORD dw_byte_written = 0;
        DWORD dw_byte_read = 0;
        uint8_t mode_signal = MODE_TEST_HELLO;

        //MODE signalling
        if (WriteFile(comport_handle, &mode_signal, 1, &dw_byte_written, NULL)) {
            fprintf(stderr, "[  OK  ] MODE 0x%02X\n", mode_signal);
        }
        else {
            fprintf(stderr, "[FAILED] MODE 0x%02X\n", mode_signal);
            return;
        }

        if (ReadFile(comport_handle, data_read, 16, &dw_byte_read, NULL)) {
            fprintf(stderr, "[  OK  ] Response: ");
            for (int i = 0; i < 16; ++i) {
                fprintf(stderr, "%c", data_read[i]);
            }
            fprintf(stderr, "\n");
        }
        else {
            fprintf(stderr, "[FAILED] Response\n");
            return;
        }

    }

    void test_echo(void* comport_handle) {
        DWORD dw_byte_written = 0;
        DWORD dw_byte_read = 0;
        uint8_t mode_signal = MODE_TEST_ECHO;

        char send_string[16] = "Test echo abcde";

        //MODE signalling
        if (WriteFile(comport_handle, &mode_signal, 1, &dw_byte_written, NULL)) {
            fprintf(stderr, "[  OK  ] MODE 0x%02X\n", mode_signal);
        }
        else {
            fprintf(stderr, "[FAILED] MODE 0x%02X\n", mode_signal);
            return;
        }

        if (WriteFile(comport_handle, send_string, 16, &dw_byte_written, NULL)) {
            fprintf(stderr, "[  OK  ] SEND:");
            for (int i = 0; i < 16; i++) {
                fprintf(stderr, "%c", send_string[i]);
            }
            fprintf(stderr, "\n");
        }
        else {
            fprintf(stderr, "[FAILED] SEND");
            return;
        }

        if (ReadFile(comport_handle, data_read, 16, &dw_byte_read, NULL)) {
            fprintf(stderr, "[  OK  ] Response: ");
            for (int i = 0; i < 16; ++i) {
                fprintf(stderr, "%c", data_read[i]);
            }
            fprintf(stderr, "\n");
        }
        else {
            fprintf(stderr, "[FAILED] Response\n");
            return;
        }
    }


    void write_from_file_to_fpga(void* comport_handle, const char* file_name, uint32_t base_addr, uint32_t words_to_send) {
        //file name -> name of file to send. assuming txt file
        //words to send -> number of words in file
        //open file
        FILE* f_send = fopen(file_name, "r");

        //allocate buffer and read file to buffer
        uint32_t* buffer = (uint32_t*)calloc(words_to_send, sizeof(uint32_t));
        uint32_t temp0, temp1;

        if (f_send != NULL) {
            for (int i = 0; i < words_to_send; ++i) 
                fscanf_s(f_send, "%X", &buffer[i]);
        }


        fclose(f_send);

        //send 1-byte command to board
        DWORD dw_byte_written = 0;
        DWORD dw_byte_read = 0;
        uint8_t mode_signal = MODE_STORE_RAM;

        if (WriteFile(comport_handle, &mode_signal, 1, &dw_byte_written, NULL)) {
            fprintf(stderr, "[  OK  ] MODE 0x%02X\n", mode_signal);
        }
        else {
            fprintf(stderr, "[FAILED] MODE 0x%02X\n", mode_signal);
            return;
        }

        //check if FPGA has received mode signal
        if (ReadFile(comport_handle, data_read, 16, &dw_byte_read, NULL)) {	//expected response is "Waiting CMD"
            fprintf(stderr, "[  OK  ] Response: ");
            for (int i = 0; i < 16; ++i) {
                fprintf(stderr, "%c", data_read[i]);
            }
            fprintf(stderr, "\n");
        }
        else {
            fprintf(stderr, "[FAILED] Response\n");
            return;
        }


        //send file metadata(DRAM base addr / file size)
        uint32_t encoded_data[2];
        encoded_data[0] = base_addr;
        encoded_data[1] = words_to_send;

        if (WriteFile(comport_handle, &encoded_data, 8, &dw_byte_written, NULL)) {
            fprintf(stderr, "[  OK  ] SEND CMD\n");
        }
        else {
            fprintf(stderr, "[FAILED] SEND CMD\n");
            return;
        }

        if (ReadFile(comport_handle, &data_read, 16, &dw_byte_read, NULL)) { //expected response is "CMD receive"
            fprintf(stderr, "[  OK  ] Response: ");
            for (int i = 0; i < 16; i++) {
                fprintf(stderr, "%c", data_read[i]);
            }
            fprintf(stderr, "\n");
        }
        else {
            fprintf(stderr, "[FAILED] Resonse:\n");
            return;
        }


        //send file

        uint32_t count;

        count = 0;
        while (count < words_to_send) {
            if (WriteFile(comport_handle, (buffer + count), words_to_send * sizeof(uint32_t) / 16, &dw_byte_written, NULL)) {
                fprintf(stderr, "[  OK  ] SEND %s\t%d\n", file_name, count);
                count = count + words_to_send / 16;
            }
            else {
                fprintf(stderr, "[FAILED] SEND %s\n", file_name);
                return;
            }
        }


        //get response
        if (ReadFile(comport_handle, &data_read, 16, &dw_byte_read, NULL)) { //expected response is "Store complete"
            fprintf(stderr, "[  OK  ] Response: ");
            for (int i = 0; i < 16; i++) {
                fprintf(stderr, "%c", data_read[i]);
            }
            fprintf(stderr, "\n");
        }
        else {
            fprintf(stderr, "[FAILED] Resonse:\n");
            return;
        }

        free(buffer);

    }

    void read_from_fpga_to_file(void* comport_handle, const char* file_name, uint32_t base_addr, uint32_t words_to_recv)
    {
        //load file from FPGA DRAM and save to txt file
        //file name -> name of file to save. assuming txt file
        //words to recv -> number of words in file

        //open file
        FILE* f_recv = fopen(file_name, "w");

        //allocate buffer and read file to buffer
        uint32_t* buffer = (uint32_t*)calloc(words_to_recv, sizeof(uint32_t));


        //send 1-byte command to board
        DWORD dw_byte_written = 0;
        DWORD dw_byte_read = 0;
        uint8_t mode_signal = MODE_LOAD_RAM;

        if (WriteFile(comport_handle, &mode_signal, 1, &dw_byte_written, NULL)) {
            fprintf(stderr, "[  OK  ] MODE 0x%02X\n", mode_signal);
        }
        else {
            fprintf(stderr, "[FAILED] MODE 0x%02X\n", mode_signal);
            return;
        }

        //check if FPGA has received mode signal
        if (ReadFile(comport_handle, data_read, 16, &dw_byte_read, NULL)) {	//expected response is "Waiting CMD"
            fprintf(stderr, "[  OK  ] Response: ");
            for (int i = 0; i < 16; ++i) {
                fprintf(stderr, "%c", data_read[i]);
            }
            fprintf(stderr, "\n");
        }
        else {
            fprintf(stderr, "[FAILED] Response\n");
            return;
        }


        //send file metadata(DRAM base addr / file size)
        uint32_t encoded_data[2];
        encoded_data[0] = base_addr;
        encoded_data[1] = words_to_recv;

        if (WriteFile(comport_handle, &encoded_data, 8, &dw_byte_written, NULL)) {
            fprintf(stderr, "[  OK  ] SEND CMD\n");
        }
        else {
            fprintf(stderr, "[FAILED] SEND CMD\n");
            return;
        }

        if (ReadFile(comport_handle, &data_read, 16, &dw_byte_read, NULL)) { //expected response is "CMD receive"
            fprintf(stderr, "[  OK  ] Response: ");
            for (int i = 0; i < 16; i++) {
                fprintf(stderr, "%c", data_read[i]);
            }
            fprintf(stderr, "\n");
        }
        else {
            fprintf(stderr, "[FAILED] Resonse:\n");
            return;
        }


        //receive file back and verify (word by word)
        uint32_t tmp_buffer;

        for (int i = 0; i < words_to_recv; i++) {
            if (ReadFile(comport_handle, &tmp_buffer, sizeof(uint32_t), &dw_byte_read, NULL)) {
                //fprintf(f_recv, "%04X\n", tmp_buffer);
                fprintf(f_recv, "%08x\n", tmp_buffer);
            }
            if (i % 256 == 0) {
                fprintf(stderr, "[LOADING] %s, Line %d\n", file_name, i);
            }
        }

        fprintf(stderr, "[  OK  ] SAVE %s\n", file_name);
        fclose(f_recv);

        free(buffer);
    }

    void verify_result(const char* src_file, const char* dst_file, uint32_t words_to_check) {

        //open file
        FILE* fp_src = fopen(src_file, "r");
        FILE* fp_dst = fopen(dst_file, "r");
        int32_t src_pixel;
        int32_t dst_pixel;
        BOOL is_identical = TRUE;

        fprintf(stderr, "[CHECK] Target: %s \n        Result: %s \n", src_file, dst_file);

        if (fp_src != NULL && fp_dst) {
            for (int i = 0; i < words_to_check ; ++i) {
                fscanf_s(fp_src, "%x", &src_pixel);
                fscanf_s(fp_dst, "%x", &dst_pixel);
                if (src_pixel != dst_pixel) {
                    fprintf(stderr, "[FAILED ] Two files are different from pixel %d\n", i);
                    is_identical = FALSE;
                    break;
                }
            }

            if(is_identical == TRUE)
                fprintf(stderr, "[DONE ] Two files are identical\n");
        }

        if (fp_src != NULL) fclose(fp_src);
        if (fp_dst != NULL) fclose(fp_dst);
    }

    void write_config(void* comport_handle) {
        //send 1-byte command to board
        DWORD dw_byte_written = 0;
        DWORD dw_byte_read = 0;
        uint8_t mode_signal = MODE_STORE_CFG;

        if (WriteFile(comport_handle, &mode_signal, 1, &dw_byte_written, NULL)) {
            fprintf(stderr, "[  OK  ] MODE 0x%02X\n", mode_signal);
        }
        else {
            fprintf(stderr, "[FAILED] MODE 0x%02X\n", mode_signal);
            return;
        }

        //check if FPGA has received mode signal
        if (ReadFile(comport_handle, data_read, 16, &dw_byte_read, NULL)) {	//expected response is "Waiting CMD"
            fprintf(stderr, "[  OK  ] Response: ");
            for (int i = 0; i < 16; ++i) {
                fprintf(stderr, "%c", data_read[i]);
            }
            fprintf(stderr, "\n");
        }
        else {
            fprintf(stderr, "[FAILED] Response\n");
            return;
        }


        //send address offset and data to store
        uint32_t encoded_data[2];
        for (uint32_t k = 0; k < 2* NUM_CONV_LAYER; k++) {
            encoded_data[0] = k;
            encoded_data[1] = base_addr_config[k];
            if (WriteFile(comport_handle, &encoded_data, 8, &dw_byte_written, NULL)) {
                fprintf(stderr, "[  OK  ] Send config address = %02d\n", k);
            }
            else {
                fprintf(stderr, "[FAILED] Send config address = %02d\n", k);
                return;
            }
        }

        if (ReadFile(comport_handle, &data_read, 16, &dw_byte_read, NULL)) { //expected response is "Store Complete"
            fprintf(stderr, "[  OK  ] Response: ");
            for (int i = 0; i < 16; i++) {
                fprintf(stderr, "%c", data_read[i]);
            }
            fprintf(stderr, "\n");
        }
        else {
            fprintf(stderr, "[FAILED] Response:\n");
            return;
        }
    }

    void start_engine(void* comport_handle) {
        //send 1-byte command to board
        DWORD dw_byte_written = 0;
        DWORD dw_byte_read = 0;
        uint8_t mode_signal = MODE_RUN_ENGINE;

        if (WriteFile(comport_handle, &mode_signal, 1, &dw_byte_written, NULL)) {
            fprintf(stderr, "[  OK  ] MODE 0x%02X\n", mode_signal);
        }
        else {
            fprintf(stderr, "[FAILED] MODE 0x%02X\n", mode_signal);
            return;
        }
        
        if (ReadFile(comport_handle, &data_read, 16, &dw_byte_read, NULL)) { //expected response is "Engine Run"
            fprintf(stderr, "[  OK  ] Response: ");
            for (int i = 0; i < 16; i++) {
                fprintf(stderr, "%c", data_read[i]);
            }
            fprintf(stderr, "\n");
        }
        else {
            fprintf(stderr, "[FAILED] Response:\n");
            return;
        }

        if (ReadFile(comport_handle, &data_read, 16, &dw_byte_read, NULL)) { //expected response is "Engine Complete"
            fprintf(stderr, "[  OK  ] Response: ");
            for (int i = 0; i < 16; i++) {
                fprintf(stderr, "%c", data_read[i]);
            }
            fprintf(stderr, "\n");
        }
        else {
            fprintf(stderr, "[FAILED] Response:\n");
            return;
        }
        return;
    }

    void write_image(char* filename, char* out_filename) {
        // Parameters
        char* cfgfile    = "C:/skeleton/bin/aix2024.cfg";
        char* weightfile = "C:/skeleton/bin/aix2024.weights";        
        char* obj_names  = "C:/skeleton/bin/yolohw.names";
        int quantized    = 1;
        int save_params  = 0;
        float thresh     = 0.24;
        int dont_show    = 1;

        // load object names
        char** names = calloc(10000, sizeof(char*));
        int obj_count = 0;
        FILE* fp;
        char buffer[255];
        fp = fopen(obj_names, "r");
        while (fgets(buffer, 255, (FILE*)fp)) {
            names[obj_count] = calloc(strlen(buffer) + 1, sizeof(char));
            strcpy(names[obj_count], buffer);
            names[obj_count][strlen(buffer) - 1] = '\0'; //remove newline
            ++obj_count;
        }
        fclose(fp);
        int classes = obj_count;        

        //image **alphabet = load_alphabet();            // image.c
        image** alphabet = NULL;
        network net = parse_network_cfg(cfgfile, 1, quantized);    // parser.c
        if (weightfile) {
            load_weights_upto_cpu(&net, weightfile, net.n);    // parser.c
        }
        //set_batch_network(&net, 1);                    // network.c
        srand(2222222);
        yolov2_fuse_conv_batchnorm(net);
        if (quantized) {
            printf("\n\n Quantization! \n\n");
            do_quantization(net);
            if (save_params) {
                printf("\n Saving quantized model... \n\n");
                save_quantized_model(net);
            }
        }

        clock_t time;
        int j;
        float nms = .4;

        image im = load_image(filename, 0, 0, 3);            // image.c
        image sized = resize_image(im, net.w, net.h);    // image.c
        layer l = net.layers[net.n - 1];

        box* boxes = calloc(l.w * l.h * l.n, sizeof(box));
        float** probs = calloc(l.w * l.h * l.n, sizeof(float*));
        for (j = 0; j < l.w * l.h * l.n; ++j) probs[j] = calloc(l.classes, sizeof(float*));

        float* X = sized.data;
        time = clock();
        if (quantized) {
            network_predict_quantized(net, X);    // quantized
            nms = 0.2;
        }
        else {
            network_predict_cpu(net, X);
        }
        printf("%s: Predicted in %f seconds.\n", filename, (float)(clock() - time) / CLOCKS_PER_SEC); //sec(clock() - time));
        
        // Update the detector with the results from FPGA
        //{{{
        //open file
        network_state state;
        state.net = net;
        state.index = 0;
        state.input = 0;
        state.truth = 0;
        state.train = 0;
        state.delta = 0;
        int8_t pixel[4];

        for (int i = 0; i < net.n; ++i) {
            layer l = net.layers[i];      
            if (l.type == YOLO) {
                printf("YOLO Layer: %02d\n", i);
                // 1. Initialize the state.input from the re
                state.input = net.layers[i - 1].output;    

                // 2. Load the output tensor from the previous layer                                                 
                char file_input_femap[100];
                    
                snprintf(file_input_femap, sizeof(file_input_femap), "C:/skeleton/bin/log_result_fpga/CONV%02d_output.hex", i - 1);
                FILE* fp = fopen(file_input_femap, "r");
                if (fp != NULL) {
                    for (int pidx = 0; pidx < l.h * l.w * l.c; pidx++) {                            
                        fscanf_s(fp, "%x", pixel, sizeof(pixel));
                        // Update the input of YOLO layers
                        state.input[pidx] = ((float)pixel[0]) / 255;
                    }
                }
                if (fp != NULL) fclose(fp);
                        
                // 3. Do forward_yolo_layer_cpu          
                forward_yolo_layer_cpu(l, state);
            }
        }
        //}}}
        
        float hier_thresh = 0.5;
        int ext_output = 1, letterbox = 0, nboxes = 0;
        detection* dets = get_network_boxes(&net, im.w, im.h, thresh, hier_thresh, 0, 1, &nboxes, letterbox);
        if (nms) do_nms_sort(dets, nboxes, l.classes, nms);
        draw_detections_v3(im, dets, nboxes, thresh, names, alphabet, l.classes, ext_output);

        if (out_filename) {
            save_image_png(im, out_filename);    // image.c
            if (!dont_show) {
                show_image(im, out_filename);    // image.c
            }
            printf("Save output file at %s\n", out_filename);
        }
        else {
            save_image_png(im, "predictions");    // image.c
            if (!dont_show) {
                show_image(im, "predictions");    // image.c
            }
        }

        free_image(im);                    // image.c
        free_image(sized);                // image.c
        free(boxes);
        free_ptrs((void**)probs, l.w * l.h * l.n);    // utils.c
        for (int i = 0; i < obj_count; ++i) 
            free(names[i]);
        free(names);            

    }
#endif